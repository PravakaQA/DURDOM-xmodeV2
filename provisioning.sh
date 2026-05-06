#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Provisioning DURDOM X-MODE PHOTO V2.1 started..."

# ====================== BASE ======================
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends \
  git wget curl aria2 unzip ca-certificates ffmpeg \
  python3-pip jq rsync
apt-get clean
rm -rf /var/lib/apt/lists/*

PIP="/venv/main/bin/pip"
PY="/venv/main/bin/python"

COMFY="/workspace/ComfyUI"
NODES="$COMFY/custom_nodes"
MODELS="$COMFY/models"
WORKFLOWS="$COMFY/user/default/workflows"

HF_HOME="/workspace/.cache/huggingface"
HF_HUB_CACHE="$HF_HOME/hub"
MODELSCOPE_CACHE="/workspace/.cache/modelscope"

mkdir -p "$NODES" "$MODELS" "$WORKFLOWS" "$HF_HOME" "$HF_HUB_CACHE" "$MODELSCOPE_CACHE"

export HF_HOME HF_HUB_CACHE MODELSCOPE_CACHE
export PIP_DISABLE_PIP_VERSION_CHECK=1
export PYTHONUNBUFFERED=1

echo "📦 Using pip: $PIP"
echo "🐍 Using python: $PY"

# ====================== HELPERS ======================
clone_or_update() {
  local repo_url="$1"
  local dir_name="$2"

  if [ -d "$NODES/$dir_name/.git" ]; then
    echo "🔄 Updating $dir_name"
    git -C "$NODES/$dir_name" fetch --all --tags || true
    git -C "$NODES/$dir_name" pull --rebase || true
  else
    echo "⬇️ Cloning $dir_name"
    git clone --depth=1 "$repo_url" "$NODES/$dir_name" || true
  fi
}

install_requirements_if_present() {
  local dir="$1"

  if [ -f "$dir/requirements.txt" ]; then
    echo "📥 Installing requirements: $dir/requirements.txt"
    "$PIP" install -r "$dir/requirements.txt" || true
  fi

  if [ -f "$dir/pyproject.toml" ]; then
    echo "📥 Installing pyproject package: $dir"
    "$PIP" install -e "$dir" || true
  fi
}

download_if_missing() {
  local url="$1"
  local out="$2"
  local dir
  dir="$(dirname "$out")"
  mkdir -p "$dir"

  if [ -s "$out" ]; then
    echo "✅ Exists: $out"
    return 0
  fi

  echo "⬇️ Downloading: $(basename "$out")"
  aria2c \
    --allow-overwrite=true \
    --auto-file-renaming=false \
    --continue=true \
    --max-connection-per-server=16 \
    --split=16 \
    --min-split-size=10M \
    --retry-wait=5 \
    --max-tries=0 \
    --summary-interval=10 \
    --dir="$dir" \
    --out="$(basename "$out")" \
    "$url"
}

symlink_if_missing() {
  local src="$1"
  local dst="$2"
  mkdir -p "$(dirname "$dst")"
  ln -sfn "$src" "$dst" || true
}

# ====================== PYTHON PACKAGES ======================
echo "📦 Installing common Python packages..."
"$PIP" install --upgrade pip setuptools wheel || true

# Не форсим полную переустановку opencv, чтобы не ломать зависимости по кругу
"$PIP" install -U \
  huggingface_hub \
  safetensors \
  transformers \
  accelerate \
  sentencepiece \
  modelscope \
  ultralytics \
  onnx \
  onnxruntime-gpu \
  segment-anything \
  opencv-python \
  opencv-python-headless \
  imageio-ffmpeg \
  scikit-image \
  einops || true

# ====================== CUSTOM NODES ======================
echo "📥 Cloning / updating custom nodes..."

# База X-Mode / старый шаблон
clone_or_update "https://github.com/chrisgoringe/cg-use-everywhere.git" "cg-use-everywhere"
clone_or_update "https://github.com/rgthree/rgthree-comfy.git" "rgthree-comfy"
clone_or_update "https://github.com/cubiq/ComfyUI_essentials.git" "ComfyUI_essentials"
clone_or_update "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git" "ComfyUI-VideoHelperSuite"
clone_or_update "https://github.com/kijai/ComfyUI-KJNodes.git" "ComfyUI-KJNodes"
clone_or_update "https://github.com/kijai/ComfyUI-WanVideoWrapper.git" "ComfyUI-WanVideoWrapper"
clone_or_update "https://github.com/kijai/ComfyUI-WanAnimatePreprocess.git" "ComfyUI-WanAnimatePreprocess"
clone_or_update "https://github.com/LeonQ8/ComfyUI-Dynamic-Lora-Scheduler.git" "ComfyUI-Dynamic-Lora-Scheduler"

# Missing nodes из нового шаблона
clone_or_update "https://github.com/ltdrdata/ComfyUI-Impact-Pack.git" "ComfyUI-Impact-Pack"
clone_or_update "https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git" "ComfyUI-Impact-Subpack"
clone_or_update "https://github.com/numz/ComfyUI-SeedVR2_VideoUpscaler.git" "ComfyUI-SeedVR2_VideoUpscaler"
clone_or_update "https://github.com/ClownsharkBatwing/RES4LYF.git" "RES4LYF"
clone_or_update "https://github.com/ZhiHui6/zhihui_nodes_comfyui.git" "zhihui_nodes_comfyui"
clone_or_update "https://github.com/Azornes/Comfyui-Resolution-Master.git" "Comfyui-Resolution-Master"
clone_or_update "https://github.com/PGCRT/CRT-Nodes.git" "CRT-Nodes"
clone_or_update "https://github.com/teskor-hub/comfyui-teskors-utils.git" "comfyui-teskors-utils"

# SAM3 оставляю тоже, т.к. у тебя он был в старом файле
clone_or_update "https://github.com/PozzettiAndrea/ComfyUI-SAM3.git" "ComfyUI-SAM3"

echo "📦 Installing requirements for custom nodes..."
for dir in "$NODES"/*; do
  [ -d "$dir" ] || continue
  install_requirements_if_present "$dir"
done

# ====================== WORKFLOWS ======================
echo "📂 Copying workflows if provisioning folder exists..."
mkdir -p "$WORKFLOWS"
cp /workspace/provisioning/*.json "$WORKFLOWS/" 2>/dev/null || true

# ====================== MODEL DIRS ======================
echo "📁 Creating model directories..."
mkdir -p \
  "$MODELS/checkpoints" \
  "$MODELS/diffusion_models" \
  "$MODELS/unet" \
  "$MODELS/vae" \
  "$MODELS/text_encoders" \
  "$MODELS/clip" \
  "$MODELS/clip_vision" \
  "$MODELS/loras" \
  "$MODELS/controlnet" \
  "$MODELS/sams" \
  "$MODELS/sam" \
  "$MODELS/ultralytics/bbox" \
  "$MODELS/ultralytics/segm" \
  "$MODELS/SEEDVR2" \
  "$MODELS/LLM"

# ====================== BASE X-MODE FILES ======================
echo "📥 Downloading base X-MODE files..."

# Эти ссылки были у тебя в старом рабочем автоскрипте
download_if_missing \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/vae.safetensors" \
  "$MODELS/vae/mo_vae.safetensors"

symlink_if_missing "$MODELS/vae/mo_vae.safetensors" "$MODELS/vae/ae.safetensors"

download_if_missing \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/klip_vision.safetensors" \
  "$MODELS/clip_vision/klip_vision.safetensors"

download_if_missing \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/text_enc.safetensors" \
  "$MODELS/text_encoders/text_enc.safetensors"

symlink_if_missing "$MODELS/text_encoders/text_enc.safetensors" "$MODELS/clip/text_enc.safetensors"

# qwen alias fix для workflow
if [ ! -s "$MODELS/text_encoders/qwen_3_4b.safetensors" ]; then
  cp -f "$MODELS/text_encoders/text_enc.safetensors" "$MODELS/text_encoders/qwen_3_4b.safetensors" || true
fi
symlink_if_missing "$MODELS/text_encoders/qwen_3_4b.safetensors" "$MODELS/clip/qwen_3_4b.safetensors"

# Основной UNET
download_if_missing \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/z_image_turbo_bf16.safetensors" \
  "$MODELS/unet/z_image_turbo_bf16.safetensors"

# ====================== CONTROLNET FIX ======================
echo "📥 Downloading Z-Image ControlNet patch..."
download_if_missing \
  "https://huggingface.co/alibaba-pai/Z-Image-Turbo-Fun-Controlnet-Union/resolve/main/Z-Image-Turbo-Fun-Controlnet-Union.safetensors" \
  "$MODELS/controlnet/Z-Image-Turbo-Fun-Controlnet-Union.safetensors"

# ====================== SEEDVR2 MODELS ======================
echo "📥 Downloading SeedVR2 models..."
download_if_missing \
  "https://huggingface.co/numz/SeedVR2_comfyUI/resolve/main/seedvr2_ema_3b_fp8_e4m3fn.safetensors" \
  "$MODELS/SEEDVR2/seedvr2_ema_3b_fp8_e4m3fn.safetensors"

download_if_missing \
  "https://huggingface.co/numz/SeedVR2_comfyUI/resolve/main/ema_vae_fp16.safetensors" \
  "$MODELS/SEEDVR2/ema_vae_fp16.safetensors"

# На случай если нода ищет ещё и в vae
symlink_if_missing "$MODELS/SEEDVR2/ema_vae_fp16.safetensors" "$MODELS/vae/ema_vae_fp16.safetensors"

# ====================== SAM / IMPACT MODELS ======================
echo "📥 Downloading SAM and detector models..."

# SAM — базовый vit_b
download_if_missing \
  "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth" \
  "$MODELS/sams/sam_vit_b_01ec64.pth"
symlink_if_missing "$MODELS/sams/sam_vit_b_01ec64.pth" "$MODELS/sam/sam_vit_b_01ec64.pth"

# Ultralytics bbox detector для Impact Subpack / FaceDetailer
download_if_missing \
  "https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8m.pt" \
  "$MODELS/ultralytics/bbox/yolov8m.pt"

# ====================== QWEN3-VL LOCAL MODEL ======================
echo "📥 Downloading Qwen3-VL-4B-Instruct into cache..."
"$PY" - <<'PY'
import os
from modelscope import snapshot_download

cache_dir = os.environ.get("MODELSCOPE_CACHE", "/workspace/.cache/modelscope")
target = None

try:
    target = snapshot_download(
        model_id="Qwen/Qwen3-VL-4B-Instruct",
        cache_dir=cache_dir
    )
    print(f"✅ Qwen3-VL-4B-Instruct cached at: {target}")
except Exception as e:
    print(f"⚠️ Qwen3-VL-4B-Instruct snapshot_download failed: {e}")
PY

# симлинк если modelscope положил модель по стандартному пути
if [ -d "$MODELSCOPE_CACHE/hub/Qwen/Qwen3-VL-4B-Instruct" ]; then
  symlink_if_missing \
    "$MODELSCOPE_CACHE/hub/Qwen/Qwen3-VL-4B-Instruct" \
    "$MODELS/LLM/Qwen3-VL-4B-Instruct"
fi

# ====================== DEFAULT LORA FOR WORKFLOW ======================
echo "📥 Downloading default workflow LoRA..."
download_if_missing \
  "https://huggingface.co/wdsfdsdf/bueno/resolve/main/bueno-z_000001250.safetensors" \
  "$MODELS/loras/bueno-z_000001250.safetensors"

# ====================== OPTIONAL USER LORA ======================
# Если захочешь, можешь просто выставить переменные окружения в template:
# USER_LORA_URL=https://huggingface.co/Durdomcore/Maeline/resolve/main/your_lora.safetensors
# USER_LORA_NAME=maeline.safetensors
if [ -n "${USER_LORA_URL:-}" ] && [ -n "${USER_LORA_NAME:-}" ]; then
  echo "📥 Downloading user LoRA from USER_LORA_URL..."
  download_if_missing "$USER_LORA_URL" "$MODELS/loras/$USER_LORA_NAME"
fi

# ====================== CACHE / PERMISSIONS ======================
echo "🧹 Fixing permissions..."
chmod -R 755 "$COMFY" || true

# ====================== SUMMARY ======================
echo ""
echo "==================== DONE ===================="
echo "Custom nodes: $NODES"
echo "Models:       $MODELS"
echo "Workflows:    $WORKFLOWS"
echo ""
echo "Installed key fixes:"
echo " - Impact Pack + Impact Subpack"
echo " - SeedVR2 custom nodes + models"
echo " - zhihui_nodes_comfyui (Qwen3VLBasic)"
echo " - Resolution-Master"
echo " - CRT-Nodes"
echo " - comfyui-teskors-utils"
echo " - Z-Image ControlNet Union patch"
echo " - qwen_3_4b.safetensors alias fix"
echo " - default bueno LoRA"
echo ""
echo "⚠️ If KJNodes still throws schema/search_aliases errors after boot,"
echo "   then the remaining issue is core-version compatibility, not downloads."
echo "=============================================="
