#!/usr/bin/env bash
set -Eeuo pipefail

echo "🚀 DURDOM X-MODE PHOTO V2.1 - PROVISION START"

export DEBIAN_FRONTEND=noninteractive
export PIP_DISABLE_PIP_VERSION_CHECK=1
export PYTHONUNBUFFERED=1
export HF_HUB_DISABLE_XET=1
export HF_HUB_ENABLE_HF_TRANSFER=0

COMFY_ROOT="${COMFY_ROOT:-/workspace/ComfyUI}"
CUSTOM_NODES_DIR="${CUSTOM_NODES_DIR:-$COMFY_ROOT/custom_nodes}"
MODELS_DIR="${MODELS_DIR:-$COMFY_ROOT/models}"
INPUT_DIR="${INPUT_DIR:-$COMFY_ROOT/input}"

VENV_PIP="${VENV_PIP:-/venv/main/bin/pip}"
PYTHON_BIN="${PYTHON_BIN:-/venv/main/bin/python}"

mkdir -p "$CUSTOM_NODES_DIR" "$MODELS_DIR" "$INPUT_DIR"

# =========================
# MODEL DIRS
# =========================
CHECKPOINTS_DIR="$MODELS_DIR/checkpoints"
DIFFUSION_DIR="$MODELS_DIR/diffusion_models"
UNET_DIR="$MODELS_DIR/unet"
TEXT_ENCODERS_DIR="$MODELS_DIR/text_encoders"
VAE_DIR="$MODELS_DIR/vae"
LORAS_DIR="$MODELS_DIR/loras"
CONTROLNET_DIR="$MODELS_DIR/controlnet"
BBOX_DIR="$MODELS_DIR/ultralytics/bbox"
SEGM_DIR="$MODELS_DIR/ultralytics/segm"
SAMS_DIR="$MODELS_DIR/sams"
SAM_DIR="$MODELS_DIR/sam"
SAM_MODELS_DIR="$MODELS_DIR/sam_models"
SEEDVR2_DIR="$MODELS_DIR/SEEDVR2"

mkdir -p \
  "$CHECKPOINTS_DIR" \
  "$DIFFUSION_DIR" \
  "$UNET_DIR" \
  "$TEXT_ENCODERS_DIR" \
  "$VAE_DIR" \
  "$LORAS_DIR" \
  "$CONTROLNET_DIR" \
  "$BBOX_DIR" \
  "$SEGM_DIR" \
  "$SAMS_DIR" \
  "$SAM_DIR" \
  "$SAM_MODELS_DIR" \
  "$SEEDVR2_DIR"

# =========================
# APT / PIP
# =========================
echo "📦 Installing system packages..."
apt-get update -y
apt-get install -y \
  git wget curl aria2 unzip rsync ca-certificates jq \
  libgl1 libglib2.0-0 build-essential

echo "🐍 Installing python deps..."
if [ -x "$VENV_PIP" ]; then
  "$VENV_PIP" install --upgrade pip setuptools wheel
  "$VENV_PIP" install --upgrade huggingface_hub hf_transfer safetensors
else
  pip install --upgrade pip setuptools wheel
  pip install --upgrade huggingface_hub hf_transfer safetensors
fi

# =========================
# HELPERS
# =========================
log() {
  echo -e "$1"
}

ensure_file_nonzero() {
  local f="$1"
  if [ ! -s "$f" ]; then
    echo "❌ File missing or empty: $f"
    exit 1
  fi
}

download_with_aria2() {
  local url="$1"
  local out_dir="$2"
  local out_name="$3"

  mkdir -p "$out_dir"

  log "⬇️ Downloading: $out_name"
  aria2c \
    --allow-overwrite=true \
    --continue=true \
    --max-connection-per-server=16 \
    --split=16 \
    --min-split-size=1M \
    --dir="$out_dir" \
    --out="$out_name" \
    "$url"

  ensure_file_nonzero "$out_dir/$out_name"
}

download_if_missing() {
  local url="$1"
  local out_dir="$2"
  local out_name="$3"

  if [ -s "$out_dir/$out_name" ]; then
    log "✅ Exists: $out_name"
    return 0
  fi

  download_with_aria2 "$url" "$out_dir" "$out_name"
}

clone_or_update_node() {
  local repo="$1"
  local dir_name="$2"
  local target="$CUSTOM_NODES_DIR/$dir_name"

  if [ -d "$target/.git" ]; then
    log "🔄 Updating node: $dir_name"
    git -C "$target" pull --ff-only || true
  else
    log "📥 Cloning node: $dir_name"
    git clone --depth 1 "$repo" "$target"
  fi
}

install_requirements_if_present() {
  local node_dir="$1"
  if [ -f "$node_dir/requirements.txt" ]; then
    log "📚 Installing requirements: $(basename "$node_dir")"
    if [ -x "$VENV_PIP" ]; then
      "$VENV_PIP" install -r "$node_dir/requirements.txt" || true
    else
      pip install -r "$node_dir/requirements.txt" || true
    fi
  fi
}

# =========================
# CUSTOM NODES
# =========================
log "🧩 Installing custom nodes..."

clone_or_update_node "https://github.com/rgthree/rgthree-comfy.git" "rgthree-comfy"
clone_or_update_node "https://github.com/ltdrdata/ComfyUI-Impact-Pack.git" "ComfyUI-Impact-Pack"
clone_or_update_node "https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git" "ComfyUI-Impact-Subpack"
clone_or_update_node "https://github.com/kijai/ComfyUI-KJNodes.git" "ComfyUI-KJNodes"
clone_or_update_node "https://github.com/cubiq/ComfyUI_essentials.git" "ComfyUI_essentials"
clone_or_update_node "https://github.com/chrisgoringe/cg-use-everywhere.git" "cg-use-everywhere"
clone_or_update_node "https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git" "ComfyUI-Custom-Scripts"
clone_or_update_node "https://github.com/ZhiHui6/zhihui_nodes_comfyui.git" "zhihui_nodes_comfyui"
clone_or_update_node "https://github.com/fsdymy/ComfyUI_fsdymy.git" "ComfyUI_fsdymy"
clone_or_update_node "https://github.com/shiimizu/ComfyUI-TinyBreaker.git" "ComfyUI-TinyBreaker" || true
clone_or_update_node "https://github.com/AlnVX/ComfyUI-SeedVR2_VideoUpscaler.git" "ComfyUI-SeedVR2_VideoUpscaler" || true
clone_or_update_node "https://github.com/azornes/ComfyUI-ResolutionMaster.git" "ComfyUI-ResolutionMaster" || true
clone_or_update_node "https://github.com/crt-nodes/CRT-Nodes.git" "CRT-Nodes" || true
clone_or_update_node "https://github.com/pythongosssss/ComfyUI-WD14-Tagger.git" "ComfyUI-WD14-Tagger" || true

log "📚 Installing custom node requirements..."
for node in "$CUSTOM_NODES_DIR"/*; do
  [ -d "$node" ] || continue
  install_requirements_if_present "$node"
done

# =========================
# CORE MODELS
# =========================
log "🧠 Downloading core models..."

# === ОСТАВЛЯЕМ ИМЕННО ЭТОТ FIX ДЛЯ QWEN / T5 SIZE ===
download_if_missing \
  "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors" \
  "$TEXT_ENCODERS_DIR" \
  "qwen_3_4b.safetensors"

download_if_missing \
  "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors" \
  "$DIFFUSION_DIR" \
  "z_image_turbo_bf16.safetensors"

download_if_missing \
  "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors" \
  "$VAE_DIR" \
  "ae.safetensors"

download_if_missing \
  "https://huggingface.co/alibaba-pai/Z-Image-Turbo-Fun-Controlnet-Union/resolve/main/Z-Image-Turbo-Fun-Controlnet-Union.safetensors" \
  "$CONTROLNET_DIR" \
  "Z-Image-Turbo-Fun-Controlnet-Union.safetensors"

# =========================
# LORA
# =========================
log "🎨 Downloading LoRA..."

download_if_missing \
  "https://huggingface.co/Durdomcore/Maeline/resolve/ff1cff370485174914b9644df0d5450e2fe8c2cb/bueno-z_000001250.safetensors" \
  "$LORAS_DIR" \
  "bueno-z_000001250.safetensors"

# =========================
# SAM FIX
# =========================
log "🩹 SAM fix..."

download_if_missing \
  "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth" \
  "$SAMS_DIR" \
  "sam_vit_b_01ec64.pth"

mkdir -p "$SAM_DIR" "$SAM_MODELS_DIR" "$MODELS_DIR/sams"

ln -sfn "$SAMS_DIR/sam_vit_b_01ec64.pth" "$SAM_DIR/sam_vit_b_01ec64.pth"
ln -sfn "$SAMS_DIR/sam_vit_b_01ec64.pth" "$SAM_MODELS_DIR/sam_vit_b_01ec64.pth"
ln -sfn "$SAMS_DIR/sam_vit_b_01ec64.pth" "$MODELS_DIR/sams/sam_vit_b_01ec64.pth"

# Доп. совместимость для разных паков
ln -sfn "$SAMS_DIR" "$MODELS_DIR/sam_folder" 2>/dev/null || true
ln -sfn "$SAMS_DIR" "$MODELS_DIR/sam_repository" 2>/dev/null || true

# =========================
# IMPACT / BBOX MODELS
# =========================
log "🎯 Downloading bbox / detector models..."

download_if_missing \
  "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8s.pt" \
  "$BBOX_DIR" \
  "face_yolov8s.pt"

download_if_missing \
  "https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov8s.pt" \
  "$BBOX_DIR" \
  "hand_yolov8s.pt"

# Если workflow ожидает Eyeful_v2-Paired.pt, делаем совместимый алиас
ln -sfn "$BBOX_DIR/face_yolov8s.pt" "$BBOX_DIR/Eyeful_v2-Paired.pt"

# Если workflow ожидает bbox/hand_yolov8s.pt по другому имени
ln -sfn "$BBOX_DIR/hand_yolov8s.pt" "$BBOX_DIR/bbox_hand_yolov8s.pt" 2>/dev/null || true

# =========================
# SEEDVR2
# =========================
log "🎥 Downloading SeedVR2 models..."

download_if_missing \
  "https://huggingface.co/AlnVX/SeedVR2_VideoUpscaler/resolve/main/seedvr2_7b_fp16.safetensors" \
  "$SEEDVR2_DIR" \
  "seedvr2_7b_fp16.safetensors" || true

download_if_missing \
  "https://huggingface.co/AlnVX/SeedVR2_VideoUpscaler/resolve/main/seedvr2_vae_fp16.safetensors" \
  "$SEEDVR2_DIR" \
  "seedvr2_vae_fp16.safetensors" || true

# =========================
# EXTRA COMPATIBILITY LINKS
# =========================
log "🔗 Creating compatibility symlinks..."

# Иногда паки ищут z-image в unet
ln -sfn "$DIFFUSION_DIR/z_image_turbo_bf16.safetensors" "$UNET_DIR/z_image_turbo_bf16.safetensors" 2>/dev/null || true

# Иногда паки ищут qwen в clip или text encoder под тем же именем
mkdir -p "$MODELS_DIR/clip"
ln -sfn "$TEXT_ENCODERS_DIR/qwen_3_4b.safetensors" "$MODELS_DIR/clip/qwen_3_4b.safetensors" 2>/dev/null || true

# =========================
# FINAL ASSERTS
# =========================
log "✅ Running final checks..."

REQUIRED_FILES=(
  "$TEXT_ENCODERS_DIR/qwen_3_4b.safetensors"
  "$DIFFUSION_DIR/z_image_turbo_bf16.safetensors"
  "$VAE_DIR/ae.safetensors"
  "$CONTROLNET_DIR/Z-Image-Turbo-Fun-Controlnet-Union.safetensors"
  "$LORAS_DIR/bueno-z_000001250.safetensors"
  "$SAMS_DIR/sam_vit_b_01ec64.pth"
  "$BBOX_DIR/face_yolov8s.pt"
  "$BBOX_DIR/hand_yolov8s.pt"
)

for f in "${REQUIRED_FILES[@]}"; do
  ensure_file_nonzero "$f"
done

# =========================
# DEBUG OUTPUT
# =========================
echo
echo "================ FINAL DEBUG ================"
echo "-- custom_nodes --"
ls -1 "$CUSTOM_NODES_DIR" | sort || true

echo
echo "-- text_encoders --"
ls -1 "$TEXT_ENCODERS_DIR" | sort || true

echo
echo "-- diffusion_models --"
ls -1 "$DIFFUSION_DIR" | sort || true

echo
echo "-- vae --"
ls -1 "$VAE_DIR" | sort || true

echo
echo "-- loras --"
ls -1 "$LORAS_DIR" | sort || true

echo
echo "-- controlnet --"
ls -1 "$CONTROLNET_DIR" | sort || true

echo
echo "-- bbox --"
ls -1 "$BBOX_DIR" | sort || true

echo
echo "-- sams --"
ls -1 "$SAMS_DIR" | sort || true

echo "============================================"
echo "✅ DURDOM X-MODE PHOTO V2.1 - PROVISION DONE"
echo "♻️ Полностью перезапусти инстанс / ComfyUI после установки"
