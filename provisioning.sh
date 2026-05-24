#!/usr/bin/env bash
set -euo pipefail

echo "========================================"
echo "🚀 DURDOM XMODE PHOTO V2.1 — FINAL STABLE TEMPLATE"
echo "========================================"

# =========================================================
# PATHS
# =========================================================

COMFY_DIR="${COMFY_DIR:-/workspace/ComfyUI}"
CUSTOM_NODES_DIR="${CUSTOM_NODES_DIR:-$COMFY_DIR/custom_nodes}"
MODELS_DIR="${MODELS_DIR:-$COMFY_DIR/models}"
WORKFLOW_DIR="$COMFY_DIR/user/default/workflows"

CHECKPOINTS_DIR="$MODELS_DIR/checkpoints"
DIFFUSION_DIR="$MODELS_DIR/diffusion_models"
UNET_DIR="$MODELS_DIR/unet"
TEXT_ENCODERS_DIR="$MODELS_DIR/text_encoders"
CLIP_DIR="$MODELS_DIR/clip"
CLIP_VISION_DIR="$MODELS_DIR/clip_vision"
VAE_DIR="$MODELS_DIR/vae"
CONTROLNET_DIR="$MODELS_DIR/controlnet"
LORAS_DIR="$MODELS_DIR/loras"
DETECTION_DIR="$MODELS_DIR/detection"

mkdir -p \
  "$CUSTOM_NODES_DIR" \
  "$WORKFLOW_DIR" \
  "$CHECKPOINTS_DIR" \
  "$DIFFUSION_DIR" \
  "$UNET_DIR" \
  "$TEXT_ENCODERS_DIR" \
  "$CLIP_DIR" \
  "$CLIP_VISION_DIR" \
  "$VAE_DIR" \
  "$CONTROLNET_DIR" \
  "$LORAS_DIR" \
  "$DETECTION_DIR" \
  "$COMFY_DIR/input" \
  "$COMFY_DIR/output" \
  "$COMFY_DIR/temp"

# =========================================================
# ENV
# =========================================================

export DEBIAN_FRONTEND=noninteractive
export PIP_DISABLE_PIP_VERSION_CHECK=1
export PYTHONUNBUFFERED=1
export HF_HUB_DISABLE_TELEMETRY=1
export HF_HUB_DISABLE_XET=1
export HF_HUB_ENABLE_HF_TRANSFER=0
export HF_TRANSFER=0

# =========================================================
# SYSTEM PACKAGES
# =========================================================

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

# =========================================================
# PYTHON
# =========================================================

if [ -x /venv/main/bin/python ]; then
  PYTHON_BIN="/venv/main/bin/python"
else
  PYTHON_BIN="python3"
fi

echo "🐍 Python: $PYTHON_BIN"

"$PYTHON_BIN" -m pip install -U \
  "pip<26.2" \
  "setuptools<83" \
  "wheel<0.48"

"$PYTHON_BIN" -m pip install -U \
  "huggingface_hub<1.0" \
  safetensors \
  hf_transfer \
  opencv-python \
  opencv-python-headless

# =========================================================
# HELPERS
# =========================================================

clone_or_update() {
  local repo_url="$1"
  local target_dir="$2"

  if [ -d "$target_dir/.git" ]; then
    echo "🔄 Updating $(basename "$target_dir")"

    git -C "$target_dir" fetch --all --prune || true
    git -C "$target_dir" reset --hard origin/HEAD || true
    git -C "$target_dir" pull --ff-only || true

  elif [ -d "$target_dir" ]; then

    echo "⚠️ Recreating $(basename "$target_dir")"

    rm -rf "$target_dir"
    git clone --depth 1 "$repo_url" "$target_dir"

  else

    echo "📥 Cloning $(basename "$target_dir")"

    git clone --depth 1 "$repo_url" "$target_dir"
  fi
}

install_requirements_if_exist() {

  local repo_dir="$1"
  local repo_name

  repo_name="$(basename "$repo_dir")"

  if [ -f "$repo_dir/requirements.txt" ]; then
    echo "📦 Installing requirements for $repo_name"

    "$PYTHON_BIN" -m pip install \
      -r "$repo_dir/requirements.txt" || true
  fi

  if [ -f "$repo_dir/requirements-cuda.txt" ]; then
    echo "📦 Installing CUDA requirements for $repo_name"

    "$PYTHON_BIN" -m pip install \
      -r "$repo_dir/requirements-cuda.txt" || true
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

# =========================================================
# CUSTOM NODES
# =========================================================

echo "========================================"
echo "📚 CLONING CUSTOM NODES"
echo "========================================"

clone_or_update "https://github.com/kijai/ComfyUI-WanVideoWrapper.git" "$CUSTOM_NODES_DIR/ComfyUI-WanVideoWrapper"
clone_or_update "https://github.com/kijai/ComfyUI-WanAnimatePreprocess.git" "$CUSTOM_NODES_DIR/ComfyUI-WanAnimatePreprocess"
clone_or_update "https://github.com/kijai/ComfyUI-KJNodes.git" "$CUSTOM_NODES_DIR/ComfyUI-KJNodes"
clone_or_update "https://github.com/rgthree/rgthree-comfy.git" "$CUSTOM_NODES_DIR/rgthree-comfy"
clone_or_update "https://github.com/ltdrdata/ComfyUI-Impact-Pack.git" "$CUSTOM_NODES_DIR/ComfyUI-Impact-Pack"
clone_or_update "https://github.com/teskor-hub/comfyui-teskors-utils.git" "$CUSTOM_NODES_DIR/comfyui-teskors-utils"
clone_or_update "https://github.com/PozzettiAndrea/ComfyUI-SAM3.git" "$CUSTOM_NODES_DIR/ComfyUI-SAM3"
clone_or_update "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git" "$CUSTOM_NODES_DIR/ComfyUI-VideoHelperSuite"
clone_or_update "https://github.com/ClownsharkBatwing/ComfyUI-ClownsharK.git" "$CUSTOM_NODES_DIR/ComfyUI-ClownsharK"
clone_or_update "https://github.com/cubiq/ComfyUI_essentials.git" "$CUSTOM_NODES_DIR/ComfyUI_essentials"
clone_or_update "https://github.com/LeonQ8/ComfyUI-Dynamic-Lora-Scheduler.git" "$CUSTOM_NODES_DIR/ComfyUI-Dynamic-Lora-Scheduler"
clone_or_update "https://github.com/PGCRT/CRT-Nodes.git" "$CUSTOM_NODES_DIR/CRT-Nodes"

# HF Downloader
clone_or_update "https://github.com/jnxmx/ComfyUI_HuggingFace_Downloader.git" "$CUSTOM_NODES_DIR/ComfyUI_HuggingFace_Downloader"

# =========================================================
# PINNED COMMITS
# =========================================================

echo "========================================"
echo "📌 PINNING STABLE COMMITS"
echo "========================================"

git -C "$CUSTOM_NODES_DIR/ComfyUI-KJNodes" checkout d0d61754bf7fa57f2abb4714cdf79058f5862a55 || true
git -C "$CUSTOM_NODES_DIR/CRT-Nodes" checkout 71649f7b71ad14cedb79182e65ee19edd2943374 || true

# =========================================================
# INSTALL NODE REQUIREMENTS
# =========================================================

echo "========================================"
echo "📦 INSTALLING NODE REQUIREMENTS"
echo "========================================"

for repo in "$CUSTOM_NODES_DIR"/*; do

  if [ -d "$repo" ]; then
    install_requirements_if_exist "$repo"
  fi

done

# =========================================================
# CLEAN CACHE
# =========================================================

echo "========================================"
echo "🧹 CLEANING PYTHON CACHE"
echo "========================================"

find "$CUSTOM_NODES_DIR" \
  -type d \
  -name "__pycache__" \
  -exec rm -rf {} + 2>/dev/null || true

# =========================================================
# MODELS
# =========================================================

echo "========================================"
echo "🤖 DOWNLOADING MODELS"
echo "========================================"

# MAIN MODEL

download_if_missing \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/WanModel.safetensors" \
  "$DIFFUSION_DIR" \
  "WanModel.safetensors"

# VAE

download_if_missing \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/vae.safetensors" \
  "$VAE_DIR" \
  "mo_vae.safetensors"

# CLIP VISION

download_if_missing \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/klip_vision.safetensors" \
  "$CLIP_VISION_DIR" \
  "klip_vision.safetensors"

# TEXT ENCODER

download_if_missing \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/text_enc.safetensors" \
  "$TEXT_ENCODERS_DIR" \
  "text_enc.safetensors"

copy_if_exists \
  "$TEXT_ENCODERS_DIR/text_enc.safetensors" \
  "$CLIP_DIR/text_enc.safetensors"

# LORAS

download_if_missing \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/light.safetensors" \
  "$LORAS_DIR" \
  "light.safetensors"

download_if_missing \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/wan.reworked.safetensors" \
  "$LORAS_DIR" \
  "wan_reworked.safetensors"

download_if_missing \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/WanPusa.safetensors" \
  "$LORAS_DIR" \
  "WanPusa.safetensors"

download_if_missing \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/WanFun.reworked.safetensors" \
  "$LORAS_DIR" \
  "WanFun.reworked.safetensors"

# DETECTION

download_if_missing \
  "https://huggingface.co/Wan-AI/Wan2.2-Animate-14B/resolve/main/process_checkpoint/det/yolov10m.onnx" \
  "$DETECTION_DIR" \
  "yolov10m.onnx"

download_if_missing \
  "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_model.onnx" \
  "$DETECTION_DIR" \
  "vitpose_h_wholebody_model.onnx"

download_if_missing \
  "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_data.bin" \
  "$DETECTION_DIR" \
  "vitpose_h_wholebody_data.bin"

# CONTROLNET

download_if_missing \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan21_Uni3C_controlnet_fp16.safetensors" \
  "$CONTROLNET_DIR" \
  "Wan21_Uni3C_controlnet_fp16.safetensors"

# =========================================================
# WORKFLOWS
# =========================================================

echo "========================================"
echo "📂 INSTALLING WORKFLOWS"
echo "========================================"

download_if_missing \
  "https://raw.githubusercontent.com/PravakaQA/DURDOM-xmodeV2/refs/heads/main/DURDOM%20X%20MODE%20PHOTO%20V2.1.json" \
  "$WORKFLOW_DIR" \
  "DURDOM_X_MODE_PHOTO_V2_1.json"

echo "✅ Workflow installed to:"
echo "$WORKFLOW_DIR"

# =========================================================
# FREEZE ENV
# =========================================================

echo "========================================"
echo "🧷 FREEZING ENVIRONMENT"
echo "========================================"

"$PYTHON_BIN" -m pip freeze > /workspace/frozen_requirements.txt || true

touch "$COMFY_DIR/.skip_comfyui_manager_updates"

rm -rf "$CUSTOM_NODES_DIR/ComfyUI-Manager/.cache" || true

# =========================================================
# VERIFY
# =========================================================

echo "========================================"
echo "🔎 VERIFY"
echo "========================================"

echo "--- WORKFLOWS ---"
ls -lah "$WORKFLOW_DIR" || true

echo "--- DIFFUSION ---"
ls -lah "$DIFFUSION_DIR" || true

echo "--- VAE ---"
ls -lah "$VAE_DIR" || true

echo "--- CLIP VISION ---"
ls -lah "$CLIP_VISION_DIR" || true

echo "--- TEXT ENCODERS ---"
ls -lah "$TEXT_ENCODERS_DIR" || true

echo "--- LORAS ---"
ls -lah "$LORAS_DIR" || true

echo "--- DETECTION ---"
ls -lah "$DETECTION_DIR" || true

echo "--- CONTROLNET ---"
ls -lah "$CONTROLNET_DIR" || true

# =========================================================
# FINAL
# =========================================================

echo "========================================"
echo "✅ DURDOM XMODE PHOTO V2.1 READY"
echo "========================================"

echo "1) ПОЛНОСТЬЮ пересоздай контейнер"
echo "2) НЕ НАЖИМАЙ Update All"
echo "3) дождись полного provision"
echo "4) workflow уже будет в разделе Workflows"
echo "5) если есть missing nodes — жми Check Missing"
echo "6) template pinned to stable commits"
