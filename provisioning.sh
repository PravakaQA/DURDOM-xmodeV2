#!/usr/bin/env bash
set -euo pipefail

echo "========================================"
echo "🚀 DURDOM X-MODE PHOTO V2.1 — FINAL PROVISION V2"
echo "========================================"

COMFY_DIR="${COMFY_DIR:-/workspace/ComfyUI}"
CUSTOM_NODES_DIR="${CUSTOM_NODES_DIR:-$COMFY_DIR/custom_nodes}"
MODELS_DIR="${MODELS_DIR:-$COMFY_DIR/models}"

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

mkdir -p \
  "$CUSTOM_NODES_DIR" \
  "$CHECKPOINTS_DIR" \
  "$DIFFUSION_DIR" \
  "$UNET_DIR" \
  "$TEXT_ENCODERS_DIR" \
  "$CLIP_DIR" \
  "$VAE_DIR" \
  "$MODEL_PATCHES_DIR" \
  "$LORAS_DIR" \
  "$UPSCALE_MODELS_DIR" \
  "$SEEDVR2_DIR" \
  "$SAMS_DIR" \
  "$SAM_DIR" \
  "$SAM_MODELS_DIR" \
  "$BBOX_DIR" \
  "$SEGM_DIR"

export DEBIAN_FRONTEND=noninteractive
export PIP_DISABLE_PIP_VERSION_CHECK=1
export PYTHONUNBUFFERED=1
export HF_HUB_DISABLE_TELEMETRY=1
export HF_HUB_DISABLE_XET=1
export HF_HUB_ENABLE_HF_TRANSFER=0
export HF_TRANSFER=0

APT_PKGS=(
  git
  wget
  curl
  aria2
  unzip
  jq
  rsync
  ca-certificates
  python3-pip
  ffmpeg
)

echo "📦 Installing system packages..."
apt-get update -y
apt-get install -y "${APT_PKGS[@]}"

if [ -x /venv/main/bin/python ]; then
  PYTHON_BIN="/venv/main/bin/python"
else
  PYTHON_BIN="python3"
fi

echo "🐍 Python: $PYTHON_BIN"
"$PYTHON_BIN" -m pip install -U pip setuptools wheel
"$PYTHON_BIN" -m pip install -U huggingface_hub safetensors hf_transfer

clone_or_update() {
  local repo_url="$1"
  local target_dir="$2"

  if [ -d "$target_dir/.git" ]; then
    echo "🔄 Updating $(basename "$target_dir")"
    git -C "$target_dir" fetch --all --prune || true
    git -C "$target_dir" reset --hard origin/HEAD || true
    git -C "$target_dir" pull --ff-only || true
  elif [ -d "$target_dir" ]; then
    echo "⚠️ Folder exists without .git, recreating: $(basename "$target_dir")"
    rm -rf "$target_dir"
    git clone --depth 1 "$repo_url" "$target_dir"
  else
    echo "📥 Cloning $(basename "$target_dir")"
    git clone --depth 1 "$repo_url" "$target_dir"
  fi
}

install_requirements_if_exist() {
  local repo_dir="$1"

  if [ -f "$repo_dir/requirements.txt" ]; then
    echo "📦 Installing requirements for $(basename "$repo_dir")"
    "$PYTHON_BIN" -m pip install -r "$repo_dir/requirements.txt" || true
  fi

  if [ -f "$repo_dir/requirements-cuda.txt" ]; then
    echo "📦 Installing CUDA requirements for $(basename "$repo_dir")"
    "$PYTHON_BIN" -m pip install -r "$repo_dir/requirements-cuda.txt" || true
  fi
}

download_if_missing() {
  local url="$1"
  local out_dir="$2"
  local out_name="$3"

  mkdir -p "$out_dir"

  if [ -f "$out_dir/$out_name" ] && [ -s "$out_dir/$out_name" ]; then
    echo "✅ Exists: $out_name"
    return 0
  fi

  echo "📥 Downloading: $out_name"
  rm -f "$out_dir/$out_name.part"

  aria2c \
    --allow-overwrite=true \
    --auto-file-renaming=false \
    --continue=true \
    --max-connection-per-server=16 \
    --split=16 \
    --min-split-size=1M \
    --retry-wait=5 \
    --max-tries=0 \
    --timeout=60 \
    --file-allocation=none \
    --console-log-level=warn \
    --summary-interval=15 \
    "$url" \
    -d "$out_dir" \
    -o "$out_name"
}

copy_if_exists() {
  local src="$1"
  local dst="$2"
  if [ -f "$src" ]; then
    mkdir -p "$(dirname "$dst")"
    cp -f "$src" "$dst" || true
  fi
}

snapshot_lora_repo() {
  local repo_id="$1"
  local local_dir="$2"

  echo "📥 Syncing LoRA repo: $repo_id"
  mkdir -p "$local_dir"

  "$PYTHON_BIN" - <<PY
from huggingface_hub import snapshot_download
snapshot_download(
    repo_id="$repo_id",
    local_dir="$local_dir",
    local_dir_use_symlinks=False,
    allow_patterns=["*.safetensors", "*.ckpt", "*.pt", "*.bin"],
    resume_download=True,
)
print("LoRA repo synced:", "$repo_id")
PY
}

fallback_install_teskors_utils() {
  if [ -d "$CUSTOM_NODES_DIR/comfyui-teskors-utils" ]; then
    return 0
  fi

  echo "⚠️ Git clone for comfyui-teskors-utils failed, trying HF fallback..."
  "$PYTHON_BIN" - <<PY
import os, shutil
from huggingface_hub import snapshot_download

base = "/tmp/teskors_hf"
out = os.path.join("$CUSTOM_NODES_DIR", "comfyui-teskors-utils")

snapshot_download(
    repo_id="vilone60/workbombom",
    repo_type="model",
    local_dir=base,
    local_dir_use_symlinks=False,
    allow_patterns=["comfyui-teskors-utils-main/**"],
    resume_download=True,
)

src = os.path.join(base, "comfyui-teskors-utils-main")
if os.path.isdir(src):
    if os.path.isdir(out):
        shutil.rmtree(out)
    shutil.copytree(src, out)
    print("HF fallback installed to", out)
else:
    print("HF fallback source folder not found:", src)
PY
}

echo "========================================"
echo "📚 CLONING CUSTOM NODES"
echo "========================================"

clone_or_update "https://github.com/ltdrdata/ComfyUI-Impact-Pack.git" "$CUSTOM_NODES_DIR/ComfyUI-Impact-Pack" || true
clone_or_update "https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git" "$CUSTOM_NODES_DIR/ComfyUI-Impact-Subpack" || true
clone_or_update "https://github.com/rgthree/rgthree-comfy.git" "$CUSTOM_NODES_DIR/rgthree-comfy" || true
clone_or_update "https://github.com/kijai/ComfyUI-KJNodes.git" "$CUSTOM_NODES_DIR/ComfyUI-KJNodes" || true
clone_or_update "https://github.com/cubiq/ComfyUI_essentials.git" "$CUSTOM_NODES_DIR/ComfyUI_essentials" || true
clone_or_update "https://github.com/chrisgoringe/cg-use-everywhere.git" "$CUSTOM_NODES_DIR/cg-use-everywhere" || true
clone_or_update "https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git" "$CUSTOM_NODES_DIR/ComfyUI-Custom-Scripts" || true
clone_or_update "https://github.com/ZhiHui6/zhihui_nodes_comfyui.git" "$CUSTOM_NODES_DIR/zhihui_nodes_comfyui" || true
clone_or_update "https://github.com/Azornes/Comfyui-Resolution-Master.git" "$CUSTOM_NODES_DIR/Comfyui-Resolution-Master" || true
clone_or_update "https://github.com/plugcrypt/CRT-Nodes.git" "$CUSTOM_NODES_DIR/CRT-Nodes" || true
clone_or_update "https://github.com/ClownsharkBatwing/RES4LYF.git" "$CUSTOM_NODES_DIR/RES4LYF" || true
clone_or_update "https://github.com/numz/ComfyUI-SeedVR2_VideoUpscaler.git" "$CUSTOM_NODES_DIR/ComfyUI-SeedVR2_VideoUpscaler" || true
clone_or_update "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git" "$CUSTOM_NODES_DIR/ComfyUI-VideoHelperSuite" || true
clone_or_update "https://github.com/WASasquatch/was-node-suite-comfyui.git" "$CUSTOM_NODES_DIR/was-node-suite-comfyui" || true
clone_or_update "https://github.com/teskor-hub/comfyui-teskors-utils.git" "$CUSTOM_NODES_DIR/comfyui-teskors-utils" || fallback_install_teskors_utils

echo "========================================"
echo "📌 PINNING TO OLD TEMPLATE COMMITS"
echo "========================================"

git -C "$CUSTOM_NODES_DIR/ComfyUI-Impact-Pack" checkout 429d0159ad429e64d2b3916e6e7be9c22d025c3c || true
git -C "$CUSTOM_NODES_DIR/ComfyUI-Impact-Subpack" checkout 50c7b71a6a224734cc9b21963c6d1926816a97f1 || true
git -C "$CUSTOM_NODES_DIR/ComfyUI-Custom-Scripts" checkout 609f3afaa74b2f88ef9ce8d939626065e3247469 || true
git -C "$CUSTOM_NODES_DIR/ComfyUI-SeedVR2_VideoUpscaler" checkout 4490bd1f482e026674543386bb2a4d176da245b9 || true
git -C "$CUSTOM_NODES_DIR/RES4LYF" checkout 0dc91c00c4c3fb38e7874fcd7a2a327765e8882c || true
git -C "$CUSTOM_NODES_DIR/zhihui_nodes_comfyui" checkout 7ce81cd4d384d8e82543574b0e26cec08a182164 || true
git -C "$CUSTOM_NODES_DIR/ComfyUI-KJNodes" checkout d0d61754bf7fa57f2abb4714cdf79058f5862a55 || true
git -C "$CUSTOM_NODES_DIR/CRT-Nodes" checkout 71649f7b71ad14cedb79182e65ee19edd2943374 || true
git -C "$CUSTOM_NODES_DIR/comfyui-teskors-utils" checkout c4a8cd1b6f8b724b055cbe371d6192e42babe103 || true
git -C "$CUSTOM_NODES_DIR/Comfyui-Resolution-Master" checkout 6f5756bb9b72047565b3f07f2a6aeb92ddce8fbe || true

echo "========================================"
echo "📦 INSTALLING NODE REQUIREMENTS"
echo "========================================"

for repo in \
  "$CUSTOM_NODES_DIR/ComfyUI-Impact-Pack" \
  "$CUSTOM_NODES_DIR/ComfyUI-Impact-Subpack" \
  "$CUSTOM_NODES_DIR/rgthree-comfy" \
  "$CUSTOM_NODES_DIR/ComfyUI-KJNodes" \
  "$CUSTOM_NODES_DIR/ComfyUI_essentials" \
  "$CUSTOM_NODES_DIR/cg-use-everywhere" \
  "$CUSTOM_NODES_DIR/ComfyUI-Custom-Scripts" \
  "$CUSTOM_NODES_DIR/zhihui_nodes_comfyui" \
  "$CUSTOM_NODES_DIR/Comfyui-Resolution-Master" \
  "$CUSTOM_NODES_DIR/CRT-Nodes" \
  "$CUSTOM_NODES_DIR/RES4LYF" \
  "$CUSTOM_NODES_DIR/ComfyUI-SeedVR2_VideoUpscaler" \
  "$CUSTOM_NODES_DIR/ComfyUI-VideoHelperSuite" \
  "$CUSTOM_NODES_DIR/was-node-suite-comfyui" \
  "$CUSTOM_NODES_DIR/comfyui-teskors-utils"
do
  [ -d "$repo" ] && install_requirements_if_exist "$repo"
done

echo "========================================"
echo "🧹 CLEANING PY CACHE"
echo "========================================"
find "$CUSTOM_NODES_DIR" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true

echo "========================================"
echo "🤖 DOWNLOADING REQUIRED MODELS"
echo "========================================"

download_if_missing \
  "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors" \
  "$CLIP_DIR" \
  "qwen_3_4b.safetensors"
copy_if_exists "$CLIP_DIR/qwen_3_4b.safetensors" "$TEXT_ENCODERS_DIR/qwen_3_4b.safetensors"

download_if_missing \
  "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors" \
  "$UNET_DIR" \
  "z_image_turbo_bf16.safetensors"
copy_if_exists "$UNET_DIR/z_image_turbo_bf16.safetensors" "$DIFFUSION_DIR/z_image_turbo_bf16.safetensors"

download_if_missing \
  "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors" \
  "$VAE_DIR" \
  "ae.safetensors"

download_if_missing \
  "https://huggingface.co/alibaba-pai/Z-Image-Turbo-Fun-Controlnet-Union/resolve/main/Z-Image-Turbo-Fun-Controlnet-Union.safetensors" \
  "$MODEL_PATCHES_DIR" \
  "Z-Image-Turbo-Fun-Controlnet-Union.safetensors"

download_if_missing \
  "https://huggingface.co/numz/SeedVR2_comfyUI/resolve/main/seedvr2_ema_7b_sharp_fp16.safetensors" \
  "$SEEDVR2_DIR" \
  "seedvr2_ema_7b_sharp_fp16.safetensors"

download_if_missing \
  "https://huggingface.co/numz/SeedVR2_comfyUI/resolve/main/ema_vae_fp16.safetensors" \
  "$SEEDVR2_DIR" \
  "ema_vae_fp16.safetensors"

download_if_missing \
  "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth" \
  "$SAMS_DIR" \
  "sam_vit_b_01ec64.pth"
copy_if_exists "$SAMS_DIR/sam_vit_b_01ec64.pth" "$SAM_DIR/sam_vit_b_01ec64.pth"
copy_if_exists "$SAMS_DIR/sam_vit_b_01ec64.pth" "$SAM_MODELS_DIR/sam_vit_b_01ec64.pth"

download_if_missing \
  "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8s.pt" \
  "$BBOX_DIR" \
  "face_yolov8s.pt"

download_if_missing \
  "https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov8s.pt" \
  "$BBOX_DIR" \
  "hand_yolov8s.pt"

copy_if_exists "$BBOX_DIR/face_yolov8s.pt" "$BBOX_DIR/Eyeful_v2-Paired.pt"

download_if_missing \
  "https://huggingface.co/gazsuv/pussydetectorv4/resolve/main/vagina-v4.2.pt" \
  "$BBOX_DIR" \
  "vagina-v4.2.pt"

download_if_missing \
  "https://huggingface.co/ashllay/YOLO_Models/resolve/main/bbox/female_breast-v4.2.pt" \
  "$BBOX_DIR" \
  "female_breast-v4.2.pt"

download_if_missing \
  "https://huggingface.co/Kentus/Adetailer/resolve/main/assdetailer-seg.pt" \
  "$BBOX_DIR" \
  "assdetailer-seg.pt"
copy_if_exists "$BBOX_DIR/assdetailer-seg.pt" "$BBOX_DIR/assdetailer.pt"

download_if_missing \
  "https://huggingface.co/gazsuv/sudoku/resolve/main/detect.safetensors" \
  "$CHECKPOINTS_DIR" \
  "detect.safetensors"

download_if_missing \
  "https://huggingface.co/gazsuv/sudoku/resolve/main/XXX.safetensors" \
  "$LORAS_DIR" \
  "XXX.safetensors"

download_if_missing \
  "https://huggingface.co/gazsuv/sudoku/resolve/main/real.safetensors" \
  "$LORAS_DIR" \
  "real.safetensors"

download_if_missing \
  "https://huggingface.co/gazsuv/sudoku/resolve/main/gpu.safetensors" \
  "$LORAS_DIR" \
  "gpu.safetensors"

download_if_missing \
  "https://huggingface.co/MochaPixel/4XUltrasharpV10/resolve/main/4xUltrasharp_4xUltrasharpV10.pt" \
  "$UPSCALE_MODELS_DIR" \
  "4xUltrasharp_4xUltrasharpV10.pt"

echo "========================================"
echo "🎨 DOWNLOADING YOUR LORA"
echo "========================================"

snapshot_lora_repo "Durdomcore/Maeline" "$LORAS_DIR/Durdomcore_Maeline"

find "$LORAS_DIR/Durdomcore_Maeline" -type f \( -iname "*.safetensors" -o -iname "*.ckpt" -o -iname "*.pt" -o -iname "*.bin" \) | while read -r f; do
  base="$(basename "$f")"
  if [ ! -f "$LORAS_DIR/$base" ]; then
    cp -f "$f" "$LORAS_DIR/$base"
  fi
done

if [ ! -f "$LORAS_DIR/bueno-z_000001250.safetensors" ]; then
  download_if_missing \
    "https://huggingface.co/Durdomcore/Maeline/resolve/ff1cff370485174914b9644df0d5450e2fe8c2cb/bueno-z_000001250.safetensors" \
    "$LORAS_DIR" \
    "bueno-z_000001250.safetensors"
fi

echo "========================================"
echo "🔎 VERIFY PINNED COMMITS"
echo "========================================"
git -C "$CUSTOM_NODES_DIR/ComfyUI-Impact-Pack" rev-parse HEAD || true
git -C "$CUSTOM_NODES_DIR/ComfyUI-Impact-Subpack" rev-parse HEAD || true
git -C "$CUSTOM_NODES_DIR/ComfyUI-Custom-Scripts" rev-parse HEAD || true
git -C "$CUSTOM_NODES_DIR/ComfyUI-SeedVR2_VideoUpscaler" rev-parse HEAD || true
git -C "$CUSTOM_NODES_DIR/RES4LYF" rev-parse HEAD || true
git -C "$CUSTOM_NODES_DIR/zhihui_nodes_comfyui" rev-parse HEAD || true
git -C "$CUSTOM_NODES_DIR/ComfyUI-KJNodes" rev-parse HEAD || true
git -C "$CUSTOM_NODES_DIR/CRT-Nodes" rev-parse HEAD || true
git -C "$CUSTOM_NODES_DIR/comfyui-teskors-utils" rev-parse HEAD || true
git -C "$CUSTOM_NODES_DIR/Comfyui-Resolution-Master" rev-parse HEAD || true

echo "========================================"
echo "🔎 FINAL CHECK"
echo "========================================"
echo "--- SAMS ---"; ls -lah "$SAMS_DIR" || true
echo "--- SAM ---"; ls -lah "$SAM_DIR" || true
echo "--- SAM_MODELS ---"; ls -lah "$SAM_MODELS_DIR" || true
echo "--- ULTRALYTICS BBOX ---"; ls -lah "$BBOX_DIR" || true
echo "--- MODEL PATCHES ---"; ls -lah "$MODEL_PATCHES_DIR" || true
echo "--- CLIP ---"; ls -lah "$CLIP_DIR" || true
echo "--- UNET ---"; ls -lah "$UNET_DIR" || true
echo "--- VAE ---"; ls -lah "$VAE_DIR" || true
echo "--- CHECKPOINTS ---"; ls -lah "$CHECKPOINTS_DIR" || true
echo "--- SEEDVR2 ---"; ls -lah "$SEEDVR2_DIR" || true
echo "--- LORAS ---"; ls -lah "$LORAS_DIR" | tail -50 || true

echo "========================================"
echo "✅ FINAL PROVISION V2 FINISHED"
echo "========================================"
echo "1) ПОЛНОСТЬЮ пересоздай контейнер"
echo "2) не жми Update All в Manager"
echo "3) дождись конца provision"
echo "4) если SAM всё ещё серый — скинь только блоки VERIFY PINNED COMMITS и FINAL CHECK"
