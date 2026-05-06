#!/usr/bin/env bash
set -euo pipefail

echo "========================================"
echo "🚀 DURDOM X-MODE PHOTO V2.1 — FULL FINAL PROVISION + MISSING NODES"
echo "========================================"

COMFY_DIR="/workspace/ComfyUI"
CUSTOM_NODES_DIR="$COMFY_DIR/custom_nodes"
MODELS_DIR="$COMFY_DIR/models"
DIFFUSION_DIR="$MODELS_DIR/diffusion_models"
TEXT_ENCODERS_DIR="$MODELS_DIR/text_encoders"
VAE_DIR="$MODELS_DIR/vae"
CONTROLNET_DIR="$MODELS_DIR/controlnet"
LORAS_DIR="$MODELS_DIR/loras"
UPSCALE_MODELS_DIR="$MODELS_DIR/upscale_models"

SAM_DIR="$MODELS_DIR/sams"
BBOX_DIR="$MODELS_DIR/ultralytics/bbox"

mkdir -p \
  "$CUSTOM_NODES_DIR" \
  "$DIFFUSION_DIR" \
  "$TEXT_ENCODERS_DIR" \
  "$VAE_DIR" \
  "$CONTROLNET_DIR" \
  "$LORAS_DIR" \
  "$UPSCALE_MODELS_DIR" \
  "$SAM_DIR" "$BBOX_DIR"

export DEBIAN_FRONTEND=noninteractive
export PIP_DISABLE_PIP_VERSION_CHECK=1
export PYTHONUNBUFFERED=1
export HF_HUB_DISABLE_TELEMETRY=1
export HF_HUB_ENABLE_HF_TRANSFER=1
export HF_TRANSFER=1

APT_PKGS=(git wget curl aria2 unzip jq rsync ca-certificates python3-pip)
echo "📦 Installing system packages..."
apt-get update -y
apt-get install -y "${APT_PKGS[@]}"

if [ -x /venv/main/bin/python ]; then
  PYTHON_BIN="/venv/main/bin/python"
  PIP_BIN="/venv/main/bin/pip"
else
  PYTHON_BIN="python3"
  PIP_BIN="python3 -m pip"
fi

echo "🐍 Python: $PYTHON_BIN"
eval "$PIP_BIN install -U pip setuptools wheel huggingface_hub hf_transfer safetensors"

# ==================== ФУНКЦИИ ====================
clone_or_update() {
  local repo_url="$1"
  local target_dir="$2"
  if [ -d "$target_dir/.git" ]; then
    echo "🔄 Updating $(basename "$target_dir")"
    git -C "$target_dir" pull --rebase || true
  else
    echo "📥 Cloning $(basename "$target_dir")"
    rm -rf "$target_dir"
    git clone --depth 1 "$repo_url" "$target_dir"
  fi
}

install_requirements_if_exist() {
  local repo_dir="$1"
  if [ -f "$repo_dir/requirements.txt" ]; then
    echo "📦 Installing requirements for $(basename "$repo_dir")"
    eval "$PIP_BIN install -r \"$repo_dir/requirements.txt\"" || true
  fi
}

download_if_missing() {
  local url="$1"
  local out_dir="$2"
  local out_name="$3"
  mkdir -p "$out_dir"
  if [ -f "$out_dir/$out_name" ]; then
    echo "✅ Exists: $out_name"
    return 0
  fi
  echo "📥 Downloading: $out_name"
  aria2c --console-log-level=warn -c -x 16 -s 16 -k 1M \
    "$url" -d "$out_dir" -o "$out_name"
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
    allow_patterns=["*.safetensors", "*.pt", "*.ckpt", "*.bin"],
    resume_download=True
)
print("LoRA repo synced:", "$repo_id")
PY
}

# ==================== CUSTOM NODES (все нужные) ====================
echo "📚 Cloning / Updating Custom Nodes..."
clone_or_update "https://github.com/ltdrdata/ComfyUI-Impact-Pack.git" "$CUSTOM_NODES_DIR/ComfyUI-Impact-Pack"
clone_or_update "https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git" "$CUSTOM_NODES_DIR/ComfyUI-Impact-Subpack"
clone_or_update "https://github.com/rgthree/rgthree-comfy.git" "$CUSTOM_NODES_DIR/rgthree-comfy"
clone_or_update "https://github.com/kijai/ComfyUI-KJNodes.git" "$CUSTOM_NODES_DIR/ComfyUI-KJNodes"
clone_or_update "https://github.com/cubiq/ComfyUI_essentials.git" "$CUSTOM_NODES_DIR/ComfyUI_essentials"
clone_or_update "https://github.com/chrisgoringe/cg-use-everywhere.git" "$CUSTOM_NODES_DIR/cg-use-everywhere"
clone_or_update "https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git" "$CUSTOM_NODES_DIR/ComfyUI-Custom-Scripts"
clone_or_update "https://github.com/ZhiHui6/zhihui_nodes_comfyui.git" "$CUSTOM_NODES_DIR/zhihui_nodes_comfyui"
clone_or_update "https://github.com/Azornes/Comfyui-Resolution-Master.git" "$CUSTOM_NODES_DIR/Comfyui-Resolution-Master"
clone_or_update "https://github.com/PGCRT/CRT-Nodes.git" "$CUSTOM_NODES_DIR/CRT-Nodes"
clone_or_update "https://github.com/ClownsharkBatwing/RES4LYF.git" "$CUSTOM_NODES_DIR/RES4LYF"
clone_or_update "https://github.com/numz/ComfyUI-SeedVR2_VideoUpscaler.git" "$CUSTOM_NODES_DIR/ComfyUI-SeedVR2_VideoUpscaler"
clone_or_update "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git" "$CUSTOM_NODES_DIR/ComfyUI-VideoHelperSuite"
clone_or_update "https://github.com/WASasquatch/was-node-suite-comfyui.git" "$CUSTOM_NODES_DIR/was-node-suite-comfyui"

echo "📦 Installing node requirements..."
for repo in \
  "$CUSTOM_NODES_DIR/ComfyUI-Impact-Pack" \
  "$CUSTOM_NODES_DIR/ComfyUI-Impact-Subpack" \
  "$CUSTOM_NODES_DIR/rgthree-comfy" \
  "$CUSTOM_NODES_DIR/ComfyUI-KJNodes" \
  "$CUSTOM_NODES_DIR/ComfyUI_essentials" \
  "$CUSTOM_NODES_DIR/cg-use-everywhere" \
  "$CUSTOM_NODES_DIR/zhihui_nodes_comfyui" \
  "$CUSTOM_NODES_DIR/Comfyui-Resolution-Master" \
  "$CUSTOM_NODES_DIR/CRT-Nodes" \
  "$CUSTOM_NODES_DIR/RES4LYF" \
  "$CUSTOM_NODES_DIR/ComfyUI-SeedVR2_VideoUpscaler"; do
  install_requirements_if_exist "$repo"
done

echo "========================================"
echo "🤖 DOWNLOADING REQUIRED MODELS"
echo "========================================"
download_if_missing \
  "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors" \
  "$DIFFUSION_DIR" "z_image_turbo_bf16.safetensors"

download_if_missing \
  "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors" \
  "$TEXT_ENCODERS_DIR" "qwen_3_4b.safetensors"

download_if_missing \
  "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors" \
  "$VAE_DIR" "ae.safetensors"

download_if_missing \
  "https://huggingface.co/alibaba-pai/Z-Image-Turbo-Fun-Controlnet-Union/resolve/main/Z-Image-Turbo-Fun-Controlnet-Union.safetensors" \
  "$CONTROLNET_DIR" "Z-Image-Turbo-Fun-Controlnet-Union.safetensors"

# SAM + Детекторы
echo "📥 SAM Model + symlinks..."
download_if_missing \
  "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth" \
  "$SAM_DIR" "sam_vit_b_01ec64.pth"

ln -sfn "$SAM_DIR" "$MODELS_DIR/sam" 2>/dev/null || true
ln -sfn "$SAM_DIR" "$MODELS_DIR/sam_models" 2>/dev/null || true

echo "📥 Ultralytics detectors..."
mkdir -p "$BBOX_DIR"
cd "$BBOX_DIR"
for m in face_yolov8s.pt hand_yolov8s.pt; do
  download_if_missing "https://huggingface.co/Bingsu/adetailer/resolve/main/$m" "$BBOX_DIR" "$m"
done
ln -sf face_yolov8s.pt Eyeful_v2-Paired.pt 2>/dev/null || true

echo "========================================"
echo "🎨 DOWNLOADING YOUR LORA"
echo "========================================"
snapshot_lora_repo "Durdomcore/Maeline" "$LORAS_DIR/Durdomcore_Maeline"

find "$LORAS_DIR/Durdomcore_Maeline" -type f \( -iname "*.safetensors" \) | while read -r f; do
  base="$(basename "$f")"
  if [ ! -f "$LORAS_DIR/$base" ]; then
    cp -f "$f" "$LORAS_DIR/$base"
  fi
done

echo "========================================"
echo "✅ FULL PROVISION FINISHED"
echo "========================================"
echo "Теперь полностью перезапусти ComfyUI"
echo "Затем зайди в Manager → Install Missing Nodes"
