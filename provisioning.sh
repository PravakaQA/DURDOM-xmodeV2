#!/usr/bin/env bash
# =====================================================================
# DURDOM X-MODE — PROVISION V3
# Поддерживает ДВА воркфлоу:
#   1) DURDOM_X_MODE_PHOTO_V2.1  (Z-Image Turbo + SeedVR2 7B + твои лоры)
#   2) X mode v1.6.2 public      (Z-Image Turbo, без SeedVR2, чекпоинт gonzalomo)
# Плюс фиксы среды: despam(sinlab) + guard + onnx + xformers/Blackwell
# =====================================================================
set -uo pipefail       # БЕЗ -e: одна упавшая закачка не убивает весь provision

# ---------- НАСТРОЙКИ ----------
# Чекпоинт для v1.6.2 (6.94 ГБ). Ставится только если INSTALL_V162=1.
INSTALL_V162="${INSTALL_V162:-0}"
# KJNodes: remove = снести (ни один X-mode воркфлоу его не использует -> 0 ошибок)
#          pin    = поставить 1.2.9 (последняя версия без несовместимых схем)
KJNODES_MODE="${KJNODES_MODE:-remove}"
GONZALOMO_URL="${GONZALOMO_URL:-https://huggingface.co/gbrx/GonzaLomo/resolve/main/gonzalomoXLFluxPony_v60PhotoXLDMD.safetensors}"
# --------------------------------

COMFY_DIR="${COMFY_DIR:-/workspace/ComfyUI}"
CUSTOM_NODES_DIR="$COMFY_DIR/custom_nodes"
MODELS_DIR="$COMFY_DIR/models"

CHECKPOINTS_DIR="$MODELS_DIR/checkpoints"
DIFFUSION_DIR="$MODELS_DIR/diffusion_models"
UNET_DIR="$MODELS_DIR/unet"
TEXT_ENCODERS_DIR="$MODELS_DIR/text_encoders"
CLIP_DIR="$MODELS_DIR/clip"
VAE_DIR="$MODELS_DIR/vae"
MODEL_PATCHES_DIR="$MODELS_DIR/model_patches"
LORAS_DIR="$MODELS_DIR/loras"
UPSCALE_MODELS_DIR="$MODELS_DIR/upscale_models"
SEEDVR2_DIR="$MODELS_DIR/SEEDVR2"
SAMS_DIR="$MODELS_DIR/sams"
SAM_DIR="$MODELS_DIR/sam"
SAM_MODELS_DIR="$MODELS_DIR/sam_models"
BBOX_DIR="$MODELS_DIR/ultralytics/bbox"
SEGM_DIR="$MODELS_DIR/ultralytics/segm"

mkdir -p "$CUSTOM_NODES_DIR" "$CHECKPOINTS_DIR" "$DIFFUSION_DIR" "$UNET_DIR" \
  "$TEXT_ENCODERS_DIR" "$CLIP_DIR" "$VAE_DIR" "$MODEL_PATCHES_DIR" "$LORAS_DIR" \
  "$UPSCALE_MODELS_DIR" "$SEEDVR2_DIR" "$SAMS_DIR" "$SAM_DIR" "$SAM_MODELS_DIR" \
  "$BBOX_DIR" "$SEGM_DIR"

export DEBIAN_FRONTEND=noninteractive
export PIP_DISABLE_PIP_VERSION_CHECK=1
export PYTHONUNBUFFERED=1
export HF_HUB_DISABLE_TELEMETRY=1
export HF_HUB_DISABLE_XET=1
export HF_HUB_ENABLE_HF_TRANSFER=0
export HF_TRANSFER=0

echo "📦 apt packages..."
apt-get update -y
apt-get install -y git wget curl aria2 unzip jq rsync ca-certificates python3-pip ffmpeg

if [ -x /venv/main/bin/python ]; then PYTHON_BIN="/venv/main/bin/python"; else PYTHON_BIN="python3"; fi
echo "🐍 Python: $PYTHON_BIN"
"$PYTHON_BIN" -m pip install -U "pip<26.2" "setuptools<83" "wheel<0.48"
"$PYTHON_BIN" -m pip install -U "huggingface_hub<1.0" safetensors hf_transfer

clone_or_update() {
  local repo_url="$1" target_dir="$2"
  if [ -d "$target_dir/.git" ]; then
    echo "🔄 $(basename "$target_dir")"
    git -C "$target_dir" fetch --all --prune || true
    git -C "$target_dir" reset --hard origin/HEAD || true
  elif [ -d "$target_dir" ]; then
    rm -rf "$target_dir"; git clone --depth 1 "$repo_url" "$target_dir"
  else
    echo "📥 $(basename "$target_dir")"; git clone --depth 1 "$repo_url" "$target_dir"
  fi
}

# ВАЖНО: git clone --depth 1 отдаёт только вершину, поэтому
# `git checkout <старый_хеш>` падает с "reference is not a tree",
# а из-за `|| true` это происходило МОЛЧА -> все пины не применялись.
# Здесь коммит сначала до-качивается, и результат печатается.
pin_commit() {
  local dir="$1" ref="$2" name
  name="$(basename "$dir")"
  [ -d "$dir/.git" ] || { echo "  ⚠️  $name: нет репозитория, пин пропущен"; return 0; }
  git -C "$dir" fetch --depth 1 origin "$ref" >/dev/null 2>&1 || git -C "$dir" fetch --unshallow >/dev/null 2>&1 || true
  if git -C "$dir" checkout -q -f "$ref" 2>/dev/null; then
    echo "  ✅ $name -> $(git -C "$dir" rev-parse --short HEAD)"
  else
    echo "  ❌ $name: коммит $ref недоступен, остаётся $(git -C "$dir" rev-parse --short HEAD)"
  fi
}

install_reqs() {
  local d="$1"
  [ -f "$d/requirements.txt" ] && "$PYTHON_BIN" -m pip install -r "$d/requirements.txt" || true
  [ -f "$d/requirements-cuda.txt" ] && "$PYTHON_BIN" -m pip install -r "$d/requirements-cuda.txt" || true
}

download_if_missing() {
  local url="$1" out_dir="$2" out_name="$3"
  [ -z "$url" ] && { echo "⏭️  Пропуск $out_name (URL не задан)"; return 0; }
  mkdir -p "$out_dir"
  if [ -f "$out_dir/$out_name" ] && [ -s "$out_dir/$out_name" ]; then echo "✅ Есть: $out_name"; return 0; fi
  echo "📥 Качаю: $out_name"
  rm -f "$out_dir/$out_name.part"
  aria2c --allow-overwrite=true --auto-file-renaming=false --continue=true \
    --max-connection-per-server=16 --split=16 --min-split-size=1M \
    --retry-wait=5 --max-tries=5 --timeout=60 --file-allocation=none \
    --console-log-level=warn --summary-interval=30 \
    "$url" -d "$out_dir" -o "$out_name" || echo "⚠️  Не скачалось: $out_name (продолжаю)"
}

copy_if_exists() {
  [ -f "$1" ] && { mkdir -p "$(dirname "$2")"; cp -f "$1" "$2" || true; }
}

fallback_teskors() {
  [ -d "$CUSTOM_NODES_DIR/comfyui-teskors-utils" ] && return 0
  "$PYTHON_BIN" - <<PY
import os, shutil
from huggingface_hub import snapshot_download
base="/tmp/teskors_hf"; out=os.path.join("$CUSTOM_NODES_DIR","comfyui-teskors-utils")
snapshot_download(repo_id="vilone60/workbombom", repo_type="model", local_dir=base,
                  local_dir_use_symlinks=False, allow_patterns=["comfyui-teskors-utils-main/**"])
src=os.path.join(base,"comfyui-teskors-utils-main")
if os.path.isdir(src):
    if os.path.isdir(out): shutil.rmtree(out)
    shutil.copytree(src,out); print("HF fallback ->",out)
PY
}

echo "========== 📚 CUSTOM NODES =========="
clone_or_update "https://github.com/ltdrdata/ComfyUI-Impact-Pack.git"            "$CUSTOM_NODES_DIR/ComfyUI-Impact-Pack"
clone_or_update "https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git"         "$CUSTOM_NODES_DIR/ComfyUI-Impact-Subpack"
clone_or_update "https://github.com/rgthree/rgthree-comfy.git"                   "$CUSTOM_NODES_DIR/rgthree-comfy"
clone_or_update "https://github.com/cubiq/ComfyUI_essentials.git"                "$CUSTOM_NODES_DIR/ComfyUI_essentials"
clone_or_update "https://github.com/chrisgoringe/cg-use-everywhere.git"          "$CUSTOM_NODES_DIR/cg-use-everywhere"
clone_or_update "https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git"    "$CUSTOM_NODES_DIR/ComfyUI-Custom-Scripts"
clone_or_update "https://github.com/ZhiHui6/zhihui_nodes_comfyui.git"            "$CUSTOM_NODES_DIR/zhihui_nodes_comfyui"
clone_or_update "https://github.com/Azornes/Comfyui-Resolution-Master.git"       "$CUSTOM_NODES_DIR/Comfyui-Resolution-Master"
clone_or_update "https://github.com/plugcrypt/CRT-Nodes.git"                     "$CUSTOM_NODES_DIR/CRT-Nodes"
clone_or_update "https://github.com/ClownsharkBatwing/RES4LYF.git"               "$CUSTOM_NODES_DIR/RES4LYF"
clone_or_update "https://github.com/numz/ComfyUI-SeedVR2_VideoUpscaler.git"      "$CUSTOM_NODES_DIR/ComfyUI-SeedVR2_VideoUpscaler"
clone_or_update "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git"    "$CUSTOM_NODES_DIR/ComfyUI-VideoHelperSuite"
clone_or_update "https://github.com/WASasquatch/was-node-suite-comfyui.git"      "$CUSTOM_NODES_DIR/was-node-suite-comfyui"
clone_or_update "https://github.com/teskor-hub/comfyui-teskors-utils.git"        "$CUSTOM_NODES_DIR/comfyui-teskors-utils" || fallback_teskors
clone_or_update "https://github.com/jnxmx/ComfyUI_HuggingFace_Downloader.git"    "$CUSTOM_NODES_DIR/ComfyUI_HuggingFace_Downloader"

# --- KJNodes: причина ошибок search_aliases / advanced / BoundingBox ---
# ПРОВЕРЕНО: ни DURDOM V2.1, ни v1.6.2 не используют ни одной KJNodes-ноды.
if [ "$KJNODES_MODE" = "remove" ]; then
  rm -rf "$CUSTOM_NODES_DIR/ComfyUI-KJNodes" "$CUSTOM_NODES_DIR/comfyui-kjnodes"
  echo "🧹 KJNodes удалён (не используется ни одним воркфлоу) — ошибок в логе не будет"
else
  clone_or_update "https://github.com/kijai/ComfyUI-KJNodes.git" "$CUSTOM_NODES_DIR/ComfyUI-KJNodes"
  # 1.2.9 — последняя версия БЕЗ search_aliases / advanced / io.BoundingBox
  pin_commit "$CUSTOM_NODES_DIR/ComfyUI-KJNodes" "f710f2635dbadbaf1ccf7d25572daa7dfec80bfd"
fi

# --- ноды ТОЛЬКО для воркфлоу v1.6.2 public (INSTALL_V162=1) ---
if [ "$INSTALL_V162" = "1" ]; then
  clone_or_update "https://github.com/crystian/ComfyUI-Crystools.git"            "$CUSTOM_NODES_DIR/ComfyUI-Crystools"
  clone_or_update "https://github.com/chflame163/ComfyUI_LayerStyle.git"         "$CUSTOM_NODES_DIR/ComfyUI_LayerStyle"
  clone_or_update "https://github.com/yolain/ComfyUI-Easy-Use.git"               "$CUSTOM_NODES_DIR/ComfyUI-Easy-Use"
  clone_or_update "https://github.com/Fannovel16/comfyui_controlnet_aux.git"     "$CUSTOM_NODES_DIR/comfyui_controlnet_aux"
  clone_or_update "https://github.com/TheLustriVA/ComfyUI-Image-Size-Tools.git"  "$CUSTOM_NODES_DIR/ComfyUI-Image-Size-Tools"
  echo "ℹ️  Если после старта ComfyUI всё ещё пишет missing nodes —"
  echo "    Manager -> Install Missing Custom Nodes (одна кнопка, доставит остаток)."
fi

echo "========== 📌 PINS (теперь реально применяются) =========="
pin_commit "$CUSTOM_NODES_DIR/ComfyUI-Impact-Pack" "429d0159ad429e64d2b3916e6e7be9c22d025c3c"
pin_commit "$CUSTOM_NODES_DIR/ComfyUI-Impact-Subpack" "50c7b71a6a224734cc9b21963c6d1926816a97f1"
pin_commit "$CUSTOM_NODES_DIR/ComfyUI-Custom-Scripts" "609f3afaa74b2f88ef9ce8d939626065e3247469"
pin_commit "$CUSTOM_NODES_DIR/ComfyUI-SeedVR2_VideoUpscaler" "4490bd1f482e026674543386bb2a4d176da245b9"
# RES4LYF: КРИТИЧНО. Июльский main использует новый io.Schema в beta/samplers.py,
# и ClownsharKSampler_Beta падает с IndexError на ComfyUI 0.8.2, когда входы
# options/guides не подключены. Январский 0dc91c00 нового API не использует.
pin_commit "$CUSTOM_NODES_DIR/RES4LYF" "0dc91c00c4c3fb38e7874fcd7a2a327765e8882c"
pin_commit "$CUSTOM_NODES_DIR/zhihui_nodes_comfyui" "7ce81cd4d384d8e82543574b0e26cec08a182164"
pin_commit "$CUSTOM_NODES_DIR/CRT-Nodes" "71649f7b71ad14cedb79182e65ee19edd2943374"
pin_commit "$CUSTOM_NODES_DIR/comfyui-teskors-utils" "c4a8cd1b6f8b724b055cbe371d6192e42babe103"
pin_commit "$CUSTOM_NODES_DIR/Comfyui-Resolution-Master" "6f5756bb9b72047565b3f07f2a6aeb92ddce8fbe"

echo "========== 📦 REQUIREMENTS =========="
for repo in "$CUSTOM_NODES_DIR"/*/ ; do [ -d "$repo" ] && install_reqs "$repo"; done
find "$CUSTOM_NODES_DIR" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true

echo "========== 🤖 МОДЕЛИ (общие для обоих воркфлоу) =========="
download_if_missing "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors" "$CLIP_DIR" "qwen_3_4b.safetensors"
copy_if_exists "$CLIP_DIR/qwen_3_4b.safetensors" "$TEXT_ENCODERS_DIR/qwen_3_4b.safetensors"

download_if_missing "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors" "$UNET_DIR" "z_image_turbo_bf16.safetensors"
copy_if_exists "$UNET_DIR/z_image_turbo_bf16.safetensors" "$DIFFUSION_DIR/z_image_turbo_bf16.safetensors"

download_if_missing "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors" "$VAE_DIR" "ae.safetensors"
download_if_missing "https://huggingface.co/alibaba-pai/Z-Image-Turbo-Fun-Controlnet-Union/resolve/main/Z-Image-Turbo-Fun-Controlnet-Union.safetensors" "$MODEL_PATCHES_DIR" "Z-Image-Turbo-Fun-Controlnet-Union.safetensors"

download_if_missing "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth" "$SAMS_DIR" "sam_vit_b_01ec64.pth"
copy_if_exists "$SAMS_DIR/sam_vit_b_01ec64.pth" "$SAM_DIR/sam_vit_b_01ec64.pth"
copy_if_exists "$SAMS_DIR/sam_vit_b_01ec64.pth" "$SAM_MODELS_DIR/sam_vit_b_01ec64.pth"

download_if_missing "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8s.pt" "$BBOX_DIR" "face_yolov8s.pt"
download_if_missing "https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov8s.pt" "$BBOX_DIR" "hand_yolov8s.pt"
download_if_missing "https://huggingface.co/gazsuv/pussydetectorv4/resolve/main/vagina-v4.2.pt" "$BBOX_DIR" "vagina-v4.2.pt"
download_if_missing "https://huggingface.co/ashllay/YOLO_Models/resolve/main/bbox/female_breast-v4.2.pt" "$BBOX_DIR" "female_breast-v4.2.pt"
download_if_missing "https://huggingface.co/Kentus/Adetailer/resolve/main/assdetailer-seg.pt" "$BBOX_DIR" "assdetailer-seg.pt"
copy_if_exists "$BBOX_DIR/assdetailer-seg.pt" "$BBOX_DIR/assdetailer.pt"
# Eyeful_v2-Paired.pt — НАСТОЯЩИЙ файл (проверено: лежит в ashllay/YOLO_Models).
download_if_missing "https://huggingface.co/ashllay/YOLO_Models/resolve/main/bbox/Eyeful_v2-Paired.pt" "$BBOX_DIR" "Eyeful_v2-Paired.pt"
# страховка: если вдруг не скачался — подставим face-детектор, чтобы нода стартовала
[ -s "$BBOX_DIR/Eyeful_v2-Paired.pt" ] || copy_if_exists "$BBOX_DIR/face_yolov8s.pt" "$BBOX_DIR/Eyeful_v2-Paired.pt"

download_if_missing "https://huggingface.co/MochaPixel/4XUltrasharpV10/resolve/main/4xUltrasharp_4xUltrasharpV10.pt" "$UPSCALE_MODELS_DIR" "4xUltrasharp_4xUltrasharpV10.pt"

echo "========== 🤖 МОДЕЛИ (только V2.1: SeedVR2 + чекпоинт детейлера) =========="
download_if_missing "https://huggingface.co/numz/SeedVR2_comfyUI/resolve/main/seedvr2_ema_7b_sharp_fp16.safetensors" "$SEEDVR2_DIR" "seedvr2_ema_7b_sharp_fp16.safetensors"
download_if_missing "https://huggingface.co/numz/SeedVR2_comfyUI/resolve/main/ema_vae_fp16.safetensors" "$SEEDVR2_DIR" "ema_vae_fp16.safetensors"
download_if_missing "https://huggingface.co/gazsuv/sudoku/resolve/main/detect.safetensors" "$CHECKPOINTS_DIR" "detect.safetensors"

echo "========== 🤖 МОДЕЛИ (только v1.6.2 public) =========="
if [ "$INSTALL_V162" = "1" ]; then
  download_if_missing "$GONZALOMO_URL" "$CHECKPOINTS_DIR" "gonzalomoXLFluxPony_v60PhotoXLDMD.safetensors"
else
  echo "⏭️  v1.6.2 не запрошен (INSTALL_V162=0) — чекпоинт 6.94 ГБ не качаю"
fi

echo "========== 📁 ПОЧИНКА путей (если Auto-Download свалил в checkpoints/bbox) =========="
if [ -d "$CHECKPOINTS_DIR/bbox" ]; then
  echo "Нашёл checkpoints/bbox — переношу детекторы в ultralytics/bbox"
  mv -n "$CHECKPOINTS_DIR/bbox/"*.pt "$BBOX_DIR/" 2>/dev/null
  rmdir "$CHECKPOINTS_DIR/bbox" 2>/dev/null
fi
for f in sam_vit_b_01ec64.pth; do
  [ -s "$SAMS_DIR/$f" ] || { FOUND=$(find "$MODELS_DIR" -name "$f" -type f 2>/dev/null | head -1); \
    [ -n "$FOUND" ] && { echo "переношу $FOUND -> $SAMS_DIR"; cp -f "$FOUND" "$SAMS_DIR/$f"; }; }
done

echo "========== 🧹 DESPAM (реклама sinlab) =========="
find "$CUSTOM_NODES_DIR" -type f -name 'ts_photo_preview.js' -delete 2>/dev/null
grep -rilaE 'location\.(replace|assign|href)[[:space:]]*=|window\.location[[:space:]]*=|Gathering applications|sinlab|landing\.html|start-here' \
  "$CUSTOM_NODES_DIR" --include=*.js --include=*.html 2>/dev/null | xargs -r rm -f
GUARD="$CUSTOM_NODES_DIR/zzz_despam_guard"; mkdir -p "$GUARD"
cat > "$GUARD/__init__.py" <<'PYEOF'
import os, re
_CN = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_S = re.compile(r"sinlab|landing\.html|start-here|Gathering applications", re.I)
_R = re.compile(r"location\.(replace|assign|href)\s*=|window\.location\s*=", re.I)
_BAD = {"ts_photo_preview.js"}
for r, d, fs in os.walk(_CN):
    if "zzz_despam_guard" in r: continue
    tk = "teskors" in r.lower()
    for fn in fs:
        if not fn.endswith((".js", ".html")): continue
        p = os.path.join(r, fn)
        try:
            if fn in _BAD: os.remove(p); print("[despam]", p); continue
            t = open(p, "r", errors="ignore").read()
            if _S.search(t) or (tk and _R.search(t)): os.remove(p); print("[despam]", p)
        except Exception: pass
NODE_CLASS_MAPPINGS = {}; NODE_DISPLAY_NAME_MAPPINGS = {}
PYEOF
echo "guard поставлена"

echo "========== 🔧 ONNX =========="
ORTSO=$(find /venv/main -path '*/onnxruntime/capi/onnxruntime_pybind11_state*.so' 2>/dev/null | head -1)
if [ -n "$ORTSO" ]; then
  NEED=$(ldd "$ORTSO" 2>/dev/null | grep -oE 'libcudart\.so\.[0-9]+' | grep -oE '[0-9]+$' | head -1)
  echo "onnxruntime требует libcudart.so.${NEED:-?}"
  if ! ldconfig -p 2>/dev/null | grep -q "libcudart.so.${NEED}"; then
    if [ "$NEED" = "13" ]; then
      "$PYTHON_BIN" -m pip install -q nvidia-cuda-runtime nvidia-cublas nvidia-cufft nvidia-curand nvidia-cudnn-cu13
    elif [ -n "$NEED" ]; then
      "$PYTHON_BIN" -m pip install -q nvidia-cuda-runtime-cu12 nvidia-cublas-cu12 nvidia-cufft-cu12 nvidia-curand-cu12 nvidia-cudnn-cu12
    fi
  fi
  PYLIB=$("$PYTHON_BIN" -c "import site;print(site.getsitepackages()[0])" 2>/dev/null)
  [ -n "$PYLIB" ] && { ls -d "$PYLIB"/nvidia/*/lib > /etc/ld.so.conf.d/zz-nvidia-onnx.conf 2>/dev/null; ldconfig; }
fi

echo "========== 🔧 XFORMERS / BLACKWELL =========="
CAPMAJ=$("$PYTHON_BIN" -c "import torch;print(torch.cuda.get_device_capability()[0] if torch.cuda.is_available() else 0)" 2>/dev/null)
echo "compute capability major = ${CAPMAJ:-?}"
if [ -n "${CAPMAJ:-}" ] && [ "$CAPMAJ" -ge 10 ] 2>/dev/null; then
  "$PYTHON_BIN" -m pip uninstall -y xformers && echo "xformers снесён -> SDPA"
else
  echo "не Blackwell — xformers не трогаю"
fi

echo "========== 🔎 FINAL CHECK =========="
for d in "$CHECKPOINTS_DIR" "$UNET_DIR" "$CLIP_DIR" "$VAE_DIR" "$MODEL_PATCHES_DIR" \
         "$LORAS_DIR" "$BBOX_DIR" "$SAMS_DIR" "$SEEDVR2_DIR" "$UPSCALE_MODELS_DIR"; do
  echo "--- $d ---"; ls -lah "$d" 2>/dev/null | tail -20
done
echo "========== 🔎 ВЕРСИИ КЛЮЧЕВЫХ НОД =========="
for n in RES4LYF ComfyUI-Impact-Pack ComfyUI-Impact-Subpack CRT-Nodes ComfyUI-SeedVR2_VideoUpscaler ComfyUI-KJNodes; do
  d="$CUSTOM_NODES_DIR/$n"
  if [ -d "$d/.git" ]; then
    printf "  %-34s %s  %s\n" "$n" "$(git -C "$d" rev-parse --short HEAD)" "$(git -C "$d" log -1 --format=%ad --date=short)"
  else
    printf "  %-34s (не установлена)\n" "$n"
  fi
done
echo "✅ PROVISION V3 DONE"
