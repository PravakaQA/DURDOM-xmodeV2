#!/usr/bin/env bash
set -euo pipefail

echo "🚀 X-MODE PHOTO V2.1 PROVISION START"

# =========================================================
# BASIC ENV
# =========================================================
export DEBIAN_FRONTEND=noninteractive
export PIP_DISABLE_PIP_VERSION_CHECK=1
export PYTHONUNBUFFERED=1
export HF_HUB_DISABLE_XET=1
export HF_HUB_ENABLE_HF_TRANSFER=0

COMFY_ROOT="${COMFY_ROOT:-/workspace/ComfyUI}"
CUSTOM_NODES_DIR="${CUSTOM_NODES_DIR:-$COMFY_ROOT/custom_nodes}"
MODELS_DIR="${MODELS_DIR:-$COMFY_ROOT/models}"
VENV_PIP="${VENV_PIP:-/venv/main/bin/pip}"

CHECKPOINTS_DIR="$MODELS_DIR/checkpoints"
DIFFUSION_DIR="$MODELS_DIR/diffusion_models"
UNET_DIR="$MODELS_DIR/unet"
TEXT_ENCODERS_DIR="$MODELS_DIR/text_encoders"
VAE_DIR="$MODELS_DIR/vae"
LORAS_DIR="$MODELS_DIR/loras"
CONTROLNET_DIR="$MODELS_DIR/controlnet"
ULTRA_DIR="$MODELS_DIR/ultralytics"
ULTRA_BBOX_DIR="$ULTRA_DIR/bbox"
SAMS_DIR="$MODELS_DIR/sams"
SAM_DIR="$MODELS_DIR/sam"
SAM_MODELS_DIR="$MODELS_DIR/sam_models"
SEEDVR2_DIR="$MODELS_DIR/SEEDVR2"

mkdir -p \
  "$CUSTOM_NODES_DIR" \
  "$CHECKPOINTS_DIR" \
  "$DIFFUSION_DIR" \
  "$UNET_DIR" \
  "$TEXT_ENCODERS_DIR" \
  "$VAE_DIR" \
  "$LORAS_DIR" \
  "$CONTROLNET_DIR" \
  "$ULTRA_BBOX_DIR" \
  "$SAMS_DIR" \
  "$SAM_DIR" \
  "$SAM_MODELS_DIR" \
  "$SEEDVR2_DIR"

# =========================================================
# APT / PYTHON
# =========================================================
echo "📦 Installing base packages..."
apt-get update
apt-get install -y git wget curl aria2 unzip rsync ca-certificates jq

if [ -x "$VENV_PIP" ]; then
  "$VENV_PIP" install --upgrade pip setuptools wheel || true
  "$VENV_PIP" install huggingface_hub hf_transfer safetensors || true
else
  pip install --upgrade pip setuptools wheel || true
  pip install huggingface_hub hf_transfer safetensors || true
fi

# =========================================================
# HELPERS
# =========================================================
download_with_aria2() {
  local url="$1"
  local out_dir="$2"
  local out_name="$3"

  mkdir -p "$out_dir"

  echo "⬇️  Downloading: $out_name"
  aria2c \
    --allow-overwrite=true \
    --auto-file-renaming=false \
    --continue=true \
    --max-tries=10 \
    --retry-wait=5 \
    --timeout=60 \
    -x 16 -s 16 -k 1M \
    --dir="$out_dir" \
    --out="$out_name" \
    "$url"
}

download_if_missing() {
  local url="$1"
  local out_dir="$2"
  local out_name="$3"

  mkdir -p "$out_dir"
  if [ -f "$out_dir/$out_name" ]; then
    echo "✅ Exists: $out_dir/$out_name"
    return 0
  fi

  if [ -z "$url" ]; then
    echo "⚠️  URL empty for $out_name, skipping direct download"
    return 1
  fi

  download_with_aria2 "$url" "$out_dir" "$out_name" || {
    echo "⚠️ aria2 failed for $out_name, trying wget..."
    wget -O "$out_dir/$out_name" "$url" || return 1
  }
}

find_existing_file() {
  local filename="$1"
  find /workspace /root "$MODELS_DIR" -type f -name "$filename" 2>/dev/null | head -n 1 || true
}

copy_or_link_existing() {
  local filename="$1"
  local dest_dir="$2"

  mkdir -p "$dest_dir"

  if [ -f "$dest_dir/$filename" ]; then
    echo "✅ Already present: $dest_dir/$filename"
    return 0
  fi

  local found
  found="$(find_existing_file "$filename")"

  if [ -n "$found" ] && [ -f "$found" ]; then
    echo "🔗 Reusing existing file for $filename -> $found"
    ln -sfn "$found" "$dest_dir/$filename" || cp -f "$found" "$dest_dir/$filename"
    return 0
  fi

  return 1
}

ensure_file() {
  local filename="$1"
  local dest_dir="$2"
  local url="${3:-}"

  copy_or_link_existing "$filename" "$dest_dir" && return 0
  download_if_missing "$url" "$dest_dir" "$filename" && return 0

  echo "❌ Could not provision $filename"
  return 1
}

clone_if_missing() {
  local repo_url="$1"
  local dir_name="$2"

  if [ -d "$CUSTOM_NODES_DIR/$dir_name/.git" ]; then
    echo "✅ Node already exists: $dir_name"
    return 0
  fi

  echo "📥 Cloning node: $dir_name"
  git clone --depth 1 "$repo_url" "$CUSTOM_NODES_DIR/$dir_name" || true
}

install_requirements_if_any() {
  local dir="$1"
  if [ -f "$dir/requirements.txt" ]; then
    echo "📦 Installing requirements: $dir"
    if [ -x "$VENV_PIP" ]; then
      "$VENV_PIP" install -r "$dir/requirements.txt" || true
    else
      pip install -r "$dir/requirements.txt" || true
    fi
  fi
}

# =========================================================
# CUSTOM NODES
# =========================================================
echo "🧩 Installing required custom nodes..."

clone_if_missing "https://github.com/ltdrdata/ComfyUI-Impact-Pack.git" "ComfyUI-Impact-Pack"
clone_if_missing "https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git" "ComfyUI-Impact-Subpack"
clone_if_missing "https://github.com/numz/ComfyUI-SeedVR2_VideoUpscaler.git" "ComfyUI-SeedVR2_VideoUpscaler"
clone_if_missing "https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git" "ComfyUI-Custom-Scripts"
clone_if_missing "https://github.com/ZhiHui6/zhihui_nodes_comfyui.git" "zhihui_nodes_comfyui"
clone_if_missing "https://github.com/PGCRT/CRT-Nodes.git" "CRT-Nodes"
clone_if_missing "https://github.com/kijai/ComfyUI-KJNodes.git" "ComfyUI-KJNodes"
clone_if_missing "https://github.com/rgthree/rgthree-comfy.git" "rgthree-comfy"
clone_if_missing "https://github.com/cubiq/ComfyUI_essentials.git" "ComfyUI_essentials"

# OPTIONAL: если у тебя в workflow реально используется teskors-utils
if [ ! -d "$CUSTOM_NODES_DIR/comfyui-teskors-utils/.git" ]; then
  git clone --depth 1 "https://github.com/teskor-hub/comfyui-teskors-utils.git" \
    "$CUSTOM_NODES_DIR/comfyui-teskors-utils" || true
fi

install_requirements_if_any "$CUSTOM_NODES_DIR/ComfyUI-Impact-Pack"
install_requirements_if_any "$CUSTOM_NODES_DIR/ComfyUI-Impact-Subpack"
install_requirements_if_any "$CUSTOM_NODES_DIR/ComfyUI-SeedVR2_VideoUpscaler"
install_requirements_if_any "$CUSTOM_NODES_DIR/ComfyUI-Custom-Scripts"
install_requirements_if_any "$CUSTOM_NODES_DIR/zhihui_nodes_comfyui"
install_requirements_if_any "$CUSTOM_NODES_DIR/CRT-Nodes"
install_requirements_if_any "$CUSTOM_NODES_DIR/ComfyUI-KJNodes"
install_requirements_if_any "$CUSTOM_NODES_DIR/rgthree-comfy"
install_requirements_if_any "$CUSTOM_NODES_DIR/ComfyUI_essentials"
install_requirements_if_any "$CUSTOM_NODES_DIR/comfyui-teskors-utils"

# =========================================================
# MODEL URLS
# =========================================================
# ---- Known / public ----
URL_SAM="https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth"

URL_FACE_YOLO="https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8s.pt?download=1"
URL_HAND_YOLO="https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov8s.pt?download=1"

URL_SEEDVR2_DIT="https://huggingface.co/numz/SeedVR2_comfyUI/resolve/main/seedvr2_ema_7b_sharp_fp16.safetensors?download=1"
URL_SEEDVR2_VAE="https://huggingface.co/numz/SeedVR2_comfyUI/resolve/main/ema_vae_fp16.safetensors?download=1"

URL_MAELINE_LORA="https://huggingface.co/Durdomcore/Maeline/resolve/ff1cff370485174914b9644df0d5450e2fe8c2cb/bueno-z_000001250.safetensors?download=1"

# ---- Optional / private / unknown exact mirrors ----
# Если у тебя есть прямые ссылки на эти файлы, просто вставь сюда.
URL_ZIMAGE_UNET="${URL_ZIMAGE_UNET:-}"
URL_ZIMAGE_CONTROLNET_UNION="${URL_ZIMAGE_CONTROLNET_UNION:-}"
URL_DETECT_CKPT="${URL_DETECT_CKPT:-}"
URL_EYEFUL="${URL_EYEFUL:-}"
URL_ASSDETAILER="${URL_ASSDETAILER:-}"
URL_FEMALE_BREAST="${URL_FEMALE_BREAST:-}"
URL_VAGINA="${URL_VAGINA:-}"
URL_TS_PREVIEW_NODE_ZIP="${URL_TS_PREVIEW_NODE_ZIP:-}"

# =========================================================
# REQUIRED FILES FROM WORKFLOW
# =========================================================
echo "🧠 Provisioning workflow files..."

# Z-IMAGE UNET
ensure_file "z_image_turbo_bf16.safetensors" "$DIFFUSION_DIR" "$URL_ZIMAGE_UNET" || true
ln -sfn "$DIFFUSION_DIR/z_image_turbo_bf16.safetensors" "$UNET_DIR/z_image_turbo_bf16.safetensors" 2>/dev/null || true

# TEXT ENCODERS / VAE / CKPTS
copy_or_link_existing "qwen_3_4b.safetensors" "$TEXT_ENCODERS_DIR" || true
copy_or_link_existing "umt5-xxl-encoder-fp8-e4m3fn-scaled.safetensors" "$TEXT_ENCODERS_DIR" || true
copy_or_link_existing "ae.safetensors" "$VAE_DIR" || true
ensure_file "detect.safetensors" "$CHECKPOINTS_DIR" "$URL_DETECT_CKPT" || true

# CONTROLNET PATCH
ensure_file "Z-Image-Turbo-Fun-Controlnet-Union.safetensors" "$CONTROLNET_DIR" "$URL_ZIMAGE_CONTROLNET_UNION" || true

# SEEDVR2
ensure_file "seedvr2_ema_7b_sharp_fp16.safetensors" "$SEEDVR2_DIR" "$URL_SEEDVR2_DIT" || true
ensure_file "ema_vae_fp16.safetensors" "$SEEDVR2_DIR" "$URL_SEEDVR2_VAE" || true

# LORA
ensure_file "bueno-z_000001250.safetensors" "$LORAS_DIR" "$URL_MAELINE_LORA" || true

# =========================================================
# SAM FIX
# =========================================================
echo "📥 SAM FIX..."
ensure_file "sam_vit_b_01ec64.pth" "$SAMS_DIR" "$URL_SAM" || true

ln -sfn "$SAMS_DIR/sam_vit_b_01ec64.pth" "$SAM_DIR/sam_vit_b_01ec64.pth" 2>/dev/null || true
ln -sfn "$SAMS_DIR/sam_vit_b_01ec64.pth" "$SAM_MODELS_DIR/sam_vit_b_01ec64.pth" 2>/dev/null || true
ln -sfn "$SAMS_DIR/sam_vit_b_01ec64.pth" "$MODELS_DIR/sam_vit_b_01ec64.pth" 2>/dev/null || true

# extra folder aliases for weird loaders
mkdir -p "$MODELS_DIR/sams_alias" || true
ln -sfn "$SAMS_DIR" "$MODELS_DIR/sams_alias" 2>/dev/null || true

# =========================================================
# ULTRALYTICS / BBOX FIX
# =========================================================
echo "🎯 Ultralytics / bbox FIX..."

ensure_file "face_yolov8s.pt" "$ULTRA_BBOX_DIR" "$URL_FACE_YOLO" || true
ensure_file "hand_yolov8s.pt" "$ULTRA_BBOX_DIR" "$URL_HAND_YOLO" || true

ensure_file "Eyeful_v2-Paired.pt" "$ULTRA_BBOX_DIR" "$URL_EYEFUL" || true
ensure_file "assdetailer.pt" "$ULTRA_BBOX_DIR" "$URL_ASSDETAILER" || true
ensure_file "female_breast-v4.2.pt" "$ULTRA_BBOX_DIR" "$URL_FEMALE_BREAST" || true
ensure_file "vagina-v4.2.pt" "$ULTRA_BBOX_DIR" "$URL_VAGINA" || true

# если Eyeful отсутствует, хотя бы временно даём fallback на face_yolov8s
if [ ! -f "$ULTRA_BBOX_DIR/Eyeful_v2-Paired.pt" ] && [ -f "$ULTRA_BBOX_DIR/face_yolov8s.pt" ]; then
  echo "🔗 Fallback: Eyeful_v2-Paired.pt -> face_yolov8s.pt"
  ln -sfn "$ULTRA_BBOX_DIR/face_yolov8s.pt" "$ULTRA_BBOX_DIR/Eyeful_v2-Paired.pt" || true
fi

# =========================================================
# OPTIONAL TS PREVIEW NODE PATCH
# =========================================================
# Если после этого останется только TSPreviewImageNoMetadata
# можно подкинуть zip-репу через URL_TS_PREVIEW_NODE_ZIP
if [ -n "$URL_TS_PREVIEW_NODE_ZIP" ] && [ ! -d "$CUSTOM_NODES_DIR/ts_preview_fix" ]; then
  echo "🧩 Installing optional TS preview node pack..."
  mkdir -p /tmp/ts_preview_fix
  download_with_aria2 "$URL_TS_PREVIEW_NODE_ZIP" /tmp "ts_preview_fix.zip" || true
  unzip -o /tmp/ts_preview_fix.zip -d /tmp/ts_preview_fix || true
  rsync -a /tmp/ts_preview_fix/ "$CUSTOM_NODES_DIR/ts_preview_fix/" || true
  install_requirements_if_any "$CUSTOM_NODES_DIR/ts_preview_fix"
fi

# =========================================================
# DEBUG OUTPUT
# =========================================================
echo ""
echo "==================== DEBUG CHECK ===================="
echo "checkpoints:"; ls -1 "$CHECKPOINTS_DIR" 2>/dev/null || true
echo ""
echo "diffusion_models:"; ls -1 "$DIFFUSION_DIR" 2>/dev/null || true
echo ""
echo "text_encoders:"; ls -1 "$TEXT_ENCODERS_DIR" 2>/dev/null || true
echo ""
echo "vae:"; ls -1 "$VAE_DIR" 2>/dev/null || true
echo ""
echo "loras:"; ls -1 "$LORAS_DIR" 2>/dev/null || true
echo ""
echo "controlnet:"; ls -1 "$CONTROLNET_DIR" 2>/dev/null || true
echo ""
echo "SEEDVR2:"; ls -1 "$SEEDVR2_DIR" 2>/dev/null || true
echo ""
echo "sams:"; ls -1 "$SAMS_DIR" 2>/dev/null || true
echo ""
echo "ultralytics/bbox:"; ls -1 "$ULTRA_BBOX_DIR" 2>/dev/null || true
echo ""
echo "custom_nodes:"; ls -1 "$CUSTOM_NODES_DIR" 2>/dev/null || true
echo "====================================================="
echo ""

echo "✅ Provision script finished"
echo "⚠️  IMPORTANT:"
echo "1) Сделай ПОЛНЫЙ restart инстанса / ComfyUI"
echo "2) Потом hard refresh страницы"
echo "3) Если останется только TSPreviewImageNoMetadata — это уже отдельный точечный node-pack"
