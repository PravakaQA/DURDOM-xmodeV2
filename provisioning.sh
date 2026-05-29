#!/usr/bin/env bash
set -euo pipefail

echo "========================================"
echo "🚀 DURDOM X-MODE PHOTO V2.1 — CLEAN FIXED PROVISION"
echo "========================================"

COMFY_DIR="${COMFY_DIR:-/workspace/ComfyUI}"
CUSTOM_NODES_DIR="${CUSTOM_NODES_DIR:-$COMFY_DIR/custom_nodes}"
MODELS_DIR="${MODELS_DIR:-$COMFY_DIR/models}"
WORKFLOWS_DIR="$COMFY_DIR/user/default/workflows"

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
  "$WORKFLOWS_DIR" \
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

echo "📦 Installing system packages..."
apt-get update -y
apt-get install -y \
  git \
  wget \
  curl \
  aria2 \
  unzip \
  jq \
  rsync \
  ca-certificates \
  python3-pip \
  ffmpeg

if [ -x /venv/main/bin/python ]; then
  PYTHON_BIN="/venv/main/bin/python"
else
  PYTHON_BIN="python3"
fi

echo "🐍 Python: $PYTHON_BIN"

echo "========================================"
echo "🧹 CLEANING WRONG / POLLUTED NODES"
echo "========================================"

# ВАЖНО: это PHOTO X-mode. Animator/WAN тут не нужны.
rm -rf "$CUSTOM_NODES_DIR/ComfyUI-WanVideoWrapper" || true
rm -rf "$CUSTOM_NODES_DIR/ComfyUI-WanAnimatePreprocess" || true
rm -rf "$CUSTOM_NODES_DIR/ComfyUI-SAM3" || true

# Убираем дубли, которые могли остаться после Manager / других скриптов
rm -rf "$CUSTOM_NODES_DIR/comfyui-kjnodes" || true
rm -rf "$CUSTOM_NODES_DIR/ComfyUI-KJNodes" || true
rm -rf "$CUSTOM_NODES_DIR/crt-nodes" || true
rm -rf "$CUSTOM_NODES_DIR/CRT-Nodes" || true
rm -rf "$CUSTOM_NODES_DIR/seedvr2_videoupscaler" || true
rm -rf "$CUSTOM_NODES_DIR/ComfyUI-SeedVR2_VideoUpscaler" || true
rm -rf "$CUSTOM_NODES_DIR/zhihui_nodes_comfyui" || true

echo "========================================"
echo "📦 PYTHON DEPS — SEEDVR2 / QWEN / XMODE FIX"
echo "========================================"

"$PYTHON_BIN" -m pip install -U "pip<26.2" "setuptools<83" "wheel<0.48"

# Фикс против flash_attn KeyError и конфликтов transformers/diffusers
"$PYTHON_BIN" -m pip uninstall -y flash-attn flash_attn || true

"$PYTHON_BIN" -m pip install --force-reinstall \
  "huggingface_hub==0.34.4" \
  "transformers==4.49.0" \
  "diffusers==0.32.2" \
  "accelerate==1.8.1" \
  "tokenizers==0.21.4" \
  "safetensors" \
  "ftfy" \
  "einops" \
  "timm" \
  "pillow" \
  "numpy" \
  "scipy" \
  "opencv-python" \
  "opencv-python-headless" \
  "imageio" \
  "imageio-ffmpeg" \
  "onnxruntime-gpu" \
  "qwen-vl-utils"

clone_fresh() {
  local repo_url="$1"
  local target_dir="$2"

  echo "📥 Cloning $(basename "$target_dir")"
  rm -rf "$target_dir"
  git clone "$repo_url" "$target_dir"
}

checkout_if_possible() {
  local repo_dir="$1"
  local ref="$2"

  if [ -d "$repo_dir/.git" ]; then
    echo "📌 Pinning $(basename "$repo_dir") → $ref"
    git -C "$repo_dir" fetch --all --tags || true
    git -C "$repo_dir" checkout "$ref" || true
  fi
}

install_requirements_if_exist() {
  local repo_dir="$1"
  local repo_name
  repo_name="$(basename "$repo_dir")"

  if [ -f "$repo_dir/requirements.txt" ]; then
    echo "📦 Installing requirements for $repo_name"
    "$PYTHON_BIN" -m pip install -r "$repo_dir/requirements.txt" || true
  fi

  if [ -f "$repo_dir/requirements-cuda.txt" ]; then
    echo "📦 Installing CUDA requirements for $repo_name"
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
echo "📚 CLONING X-MODE CUSTOM NODES"
echo "========================================"

clone_fresh "https://github.com/ltdrdata/ComfyUI-Impact-Pack.git" "$CUSTOM_NODES_DIR/ComfyUI-Impact-Pack"
clone_fresh "https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git" "$CUSTOM_NODES_DIR/ComfyUI-Impact-Subpack"
clone_fresh "https://github.com/rgthree/rgthree-comfy.git" "$CUSTOM_NODES_DIR/rgthree-comfy"
clone_fresh "https://github.com/kijai/ComfyUI-KJNodes.git" "$CUSTOM_NODES_DIR/ComfyUI-KJNodes"
clone_fresh "https://github.com/cubiq/ComfyUI_essentials.git" "$CUSTOM_NODES_DIR/ComfyUI_essentials"
clone_fresh "https://github.com/chrisgoringe/cg-use-everywhere.git" "$CUSTOM_NODES_DIR/cg-use-everywhere"
clone_fresh "https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git" "$CUSTOM_NODES_DIR/ComfyUI-Custom-Scripts"
clone_fresh "https://github.com/ZhiHui6/zhihui_nodes_comfyui.git" "$CUSTOM_NODES_DIR/zhihui_nodes_comfyui"
clone_fresh "https://github.com/Azornes/Comfyui-Resolution-Master.git" "$CUSTOM_NODES_DIR/Comfyui-Resolution-Master"
clone_fresh "https://github.com/plugcrypt/CRT-Nodes.git" "$CUSTOM_NODES_DIR/CRT-Nodes"
clone_fresh "https://github.com/ClownsharkBatwing/RES4LYF.git" "$CUSTOM_NODES_DIR/RES4LYF"
clone_fresh "https://github.com/numz/ComfyUI-SeedVR2_VideoUpscaler.git" "$CUSTOM_NODES_DIR/seedvr2_videoupscaler"
clone_fresh "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git" "$CUSTOM_NODES_DIR/ComfyUI-VideoHelperSuite"
clone_fresh "https://github.com/WASasquatch/was-node-suite-comfyui.git" "$CUSTOM_NODES_DIR/was-node-suite-comfyui"
clone_fresh "https://github.com/jnxmx/ComfyUI_HuggingFace_Downloader.git" "$CUSTOM_NODES_DIR/ComfyUI_HuggingFace_Downloader" || true

clone_fresh "https://github.com/teskor-hub/comfyui-teskors-utils.git" "$CUSTOM_NODES_DIR/comfyui-teskors-utils" || fallback_install_teskors_utils

echo "========================================"
echo "📌 PINNING OLD WORKING X-MODE COMMITS"
echo "========================================"

checkout_if_possible "$CUSTOM_NODES_DIR/ComfyUI-Impact-Pack" "429d0159ad429e64d2b3916e6e7be9c22d025c3c"
checkout_if_possible "$CUSTOM_NODES_DIR/ComfyUI-Impact-Subpack" "50c7b71a6a224734cc9b21963c6d1926816a97f1"
checkout_if_possible "$CUSTOM_NODES_DIR/ComfyUI-Custom-Scripts" "609f3afaa74b2f88ef9ce8d939626065e3247469"
checkout_if_possible "$CUSTOM_NODES_DIR/seedvr2_videoupscaler" "4490bd1f482e026674543386bb2a4d176da245b9"
checkout_if_possible "$CUSTOM_NODES_DIR/RES4LYF" "0dc91c00c4c3fb38e7874fcd7a2a327765e8882c"
checkout_if_possible "$CUSTOM_NODES_DIR/zhihui_nodes_comfyui" "7ce81cd4d384d8e82543574b0e26cec08a182164"
checkout_if_possible "$CUSTOM_NODES_DIR/ComfyUI-KJNodes" "d0d61754bf7fa57f2abb4714cdf79058f5862a55"
checkout_if_possible "$CUSTOM_NODES_DIR/CRT-Nodes" "71649f7b71ad14cedb79182e65ee19edd2943374"
checkout_if_possible "$CUSTOM_NODES_DIR/comfyui-teskors-utils" "c4a8cd1b6f8b724b055cbe371d6192e42babe103"
checkout_if_possible "$CUSTOM_NODES_DIR/Comfyui-Resolution-Master" "6f5756bb9b72047565b3f07f2a6aeb92ddce8fbe"

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
  "$CUSTOM_NODES_DIR/seedvr2_videoupscaler" \
  "$CUSTOM_NODES_DIR/ComfyUI-VideoHelperSuite" \
  "$CUSTOM_NODES_DIR/was-node-suite-comfyui" \
  "$CUSTOM_NODES_DIR/comfyui-teskors-utils" \
  "$CUSTOM_NODES_DIR/ComfyUI_HuggingFace_Downloader"
do
  [ -d "$repo" ] && install_requirements_if_exist "$repo"
done

echo "========================================"
echo "📦 FINAL DEP PIN AFTER REQUIREMENTS"
echo "========================================"

# Повторно фиксируем после requirements, потому что некоторые ноды могут перезатереть версии.
"$PYTHON_BIN" -m pip uninstall -y flash-attn flash_attn || true

"$PYTHON_BIN" -m pip install --force-reinstall \
  "huggingface_hub==0.34.4" \
  "transformers==4.49.0" \
  "diffusers==0.32.2" \
  "accelerate==1.8.1" \
  "tokenizers==0.21.4" \
  "ftfy" \
  "onnxruntime-gpu" \
  "qwen-vl-utils"

echo "========================================"
echo "📂 DOWNLOADING WORKFLOW TO COMFY WORKFLOWS"
echo "========================================"

download_if_missing \
  "https://raw.githubusercontent.com/PravakaQA/DURDOM-xmodeV2/refs/heads/main/DURDOM%20X%20MODE%20PHOTO%20V2.1.json" \
  "$WORKFLOWS_DIR" \
  "DURDOM_X_MODE_PHOTO_V2_1.json"

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
echo "🧹 CLEANING PY CACHE"
echo "========================================"

find "$CUSTOM_NODES_DIR" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true

echo "========================================"
echo "🔎 FINAL CHECK"
echo "========================================"

echo "--- WORKFLOWS ---"; ls -lah "$WORKFLOWS_DIR" || true
echo "--- CUSTOM NODES ---"; ls -lah "$CUSTOM_NODES_DIR" | head -80 || true
echo "--- SEEDVR2 NODE ---"; ls -lah "$CUSTOM_NODES_DIR/seedvr2_videoupscaler" || true
echo "--- QWEN NODE ---"; ls -lah "$CUSTOM_NODES_DIR/zhihui_nodes_comfyui" || true
echo "--- SEEDVR2 MODELS ---"; ls -lah "$SEEDVR2_DIR" || true
echo "--- CLIP ---"; ls -lah "$CLIP_DIR" || true
echo "--- TEXT_ENCODERS ---"; ls -lah "$TEXT_ENCODERS_DIR" || true
echo "--- VAE ---"; ls -lah "$VAE_DIR" || true
echo "--- MODEL PATCHES ---"; ls -lah "$MODEL_PATCHES_DIR" || true
echo "--- ULTRALYTICS BBOX ---"; ls -lah "$BBOX_DIR" || true

echo "========================================"
echo "✅ DURDOM X-MODE PHOTO V2.1 CLEAN FIXED FINISHED"
echo "========================================"
echo "1) Это PHOTO X-mode, без Animator/WAN мусора"
echo "2) SeedVR2LoadDiTModel / SeedVR2LoadVAEModel / SeedVR2VideoUpscaler должны появиться"
echo "3) Qwen3VLBasic должен появиться"
echo "4) Не жми Update All в Manager"
echo "5) После provision перезапусти ComfyUI"
