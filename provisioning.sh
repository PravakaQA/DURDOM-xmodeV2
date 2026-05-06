#!/usr/bin/env bash
set -Eeuo pipefail

# DURDOM X-MODE PHOTO V2.1 - robust auto-download / provision script
# Safe for Vast.ai / Docker / On-Start usage
# - idempotent downloads
# - creates missing folders
# - avoids broken HF Xet/CAS Python downloads by using aria2c direct URLs
# - adds SAM compatibility symlinks
# - keeps user LoRAs untouched
#
# Put this file in your repo and use it as your On-Start / provision script.

########################################
# BASIC SETTINGS
########################################
COMFY_ROOT="${COMFY_ROOT:-/workspace/ComfyUI}"
MODELS_DIR="$COMFY_ROOT/models"
CUSTOM_NODES_DIR="$COMFY_ROOT/custom_nodes"

# Optional Hugging Face token. If you have one, export HF_TOKEN in Vast env vars.
HF_TOKEN="${HF_TOKEN:-}"
HF_HEADER=()
if [[ -n "$HF_TOKEN" ]]; then
  HF_HEADER=(--header="Authorization: Bearer ${HF_TOKEN}")
fi

export HF_HUB_ENABLE_HF_TRANSFER=0
export HF_XET_HIGH_PERFORMANCE=0
export HF_HUB_DISABLE_XET=1

########################################
# HELPERS
########################################
log() {
  echo -e "\n[+] $*"
}

warn() {
  echo -e "\n[!] $*"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[x] Missing command: $1"
    exit 1
  }
}

mkdirs() {
  mkdir -p \
    "$MODELS_DIR/checkpoints" \
    "$MODELS_DIR/clip" \
    "$MODELS_DIR/clip_vision" \
    "$MODELS_DIR/configs" \
    "$MODELS_DIR/controlnet" \
    "$MODELS_DIR/diffusion_models" \
    "$MODELS_DIR/embeddings" \
    "$MODELS_DIR/gligen" \
    "$MODELS_DIR/hypernetworks" \
    "$MODELS_DIR/loras" \
    "$MODELS_DIR/photomaker" \
    "$MODELS_DIR/sams" \
    "$MODELS_DIR/style_models" \
    "$MODELS_DIR/text_encoders" \
    "$MODELS_DIR/unet" \
    "$MODELS_DIR/upscale_models" \
    "$MODELS_DIR/vae" \
    "$MODELS_DIR/vae_approx" \
    "$MODELS_DIR/ultralytics/bbox" \
    "$MODELS_DIR/ultralytics/segm" \
    "$MODELS_DIR/onnx"
}

download_file() {
  local url="$1"
  local out="$2"
  local min_size_mb="${3:-1}"
  local tmp="${out}.part"

  mkdir -p "$(dirname "$out")"

  if [[ -f "$out" ]]; then
    local actual_mb
    actual_mb=$(du -m "$out" | awk '{print $1}')
    if [[ "$actual_mb" -ge "$min_size_mb" ]]; then
      echo "[=] Exists: $out (${actual_mb} MB)"
      return 0
    fi
    warn "File too small, re-downloading: $out (${actual_mb} MB)"
    rm -f "$out"
  fi

  echo "[↓] Downloading -> $out"
  rm -f "$tmp"

  aria2c \
    --allow-overwrite=true \
    --auto-file-renaming=false \
    --continue=true \
    --max-connection-per-server=16 \
    --split=16 \
    --min-split-size=10M \
    --retry-wait=5 \
    --max-tries=0 \
    --timeout=60 \
    --summary-interval=10 \
    "${HF_HEADER[@]}" \
    -d "$(dirname "$tmp")" \
    -o "$(basename "$tmp")" \
    "$url"

  mv "$tmp" "$out"
}

clone_or_update() {
  local repo_url="$1"
  local dir_name="$2"
  local target="$CUSTOM_NODES_DIR/$dir_name"

  if [[ -d "$target/.git" ]]; then
    echo "[=] Updating node: $dir_name"
    git -C "$target" pull --ff-only || warn "Could not update $dir_name, keeping existing version"
  elif [[ -d "$target" ]]; then
    warn "$dir_name exists but is not a git repo, keeping as-is"
  else
    echo "[↓] Cloning node: $dir_name"
    git clone --depth=1 "$repo_url" "$target"
  fi
}

pip_install_if_requirements() {
  local path="$1"
  if [[ -f "$path/requirements.txt" ]]; then
    /venv/main/bin/pip install -r "$path/requirements.txt" || warn "requirements install failed for $(basename "$path")"
  fi
}

fix_sam_paths() {
  # Some templates/plugins expect /models/sam, others /models/sams.
  # Your current template uses /models/sams, but symlinks keep both compatible.
  ln -sfn "$MODELS_DIR/sams" "$MODELS_DIR/sam"
  ln -sfn "$MODELS_DIR/sams" "$MODELS_DIR/sam_models"
}

print_summary() {
  log "Provision summary"
  echo "Text encoders:"
  ls -1 "$MODELS_DIR/text_encoders" 2>/dev/null || true
  echo
  echo "Diffusion models:"
  ls -1 "$MODELS_DIR/diffusion_models" 2>/dev/null || true
  echo
  echo "VAE:"
  ls -1 "$MODELS_DIR/vae" 2>/dev/null || true
  echo
  echo "ControlNet:"
  ls -1 "$MODELS_DIR/controlnet" 2>/dev/null || true
  echo
  echo "SAMs:"
  ls -1 "$MODELS_DIR/sams" 2>/dev/null || true
  echo
  echo "LoRAs:"
  ls -1 "$MODELS_DIR/loras" 2>/dev/null || true
}

########################################
# SYSTEM SETUP
########################################
log "Installing base packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y git wget curl aria2 unzip jq ca-certificates

need_cmd git
need_cmd aria2c
need_cmd python3

mkdirs
fix_sam_paths

########################################
# OPTIONAL CUSTOM NODES
########################################
# Keep only the nodes that are commonly required by this X-Mode workflow family.
# If a node is already present, it will be updated instead of recloned.
log "Checking custom nodes"
clone_or_update https://github.com/kijai/ComfyUI-KJNodes.git ComfyUI-KJNodes
clone_or_update https://github.com/rgthree/rgthree-comfy.git rgthree-comfy
clone_or_update https://github.com/ltdrdata/ComfyUI-Impact-Pack.git ComfyUI-Impact-Pack
clone_or_update https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git ComfyUI-VideoHelperSuite
clone_or_update https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git ComfyUI-Custom-Scripts
clone_or_update https://github.com/chrisgoringe/cg-use-everywhere.git cg-use-everywhere
clone_or_update https://github.com/cubiq/ComfyUI_essentials.git ComfyUI_essentials
clone_or_update https://github.com/zhihui2023/zhihui_nodes_comfyui.git zhihui_nodes_comfyui
clone_or_update https://github.com/BadCafeCode/masquerade-nodes-comfyui.git masquerade-nodes-comfyui

for d in \
  "$CUSTOM_NODES_DIR/ComfyUI-KJNodes" \
  "$CUSTOM_NODES_DIR/rgthree-comfy" \
  "$CUSTOM_NODES_DIR/ComfyUI-Impact-Pack" \
  "$CUSTOM_NODES_DIR/ComfyUI-VideoHelperSuite" \
  "$CUSTOM_NODES_DIR/ComfyUI-Custom-Scripts" \
  "$CUSTOM_NODES_DIR/cg-use-everywhere" \
  "$CUSTOM_NODES_DIR/ComfyUI_essentials" \
  "$CUSTOM_NODES_DIR/zhihui_nodes_comfyui" \
  "$CUSTOM_NODES_DIR/masquerade-nodes-comfyui"
  do
    [[ -d "$d" ]] && pip_install_if_requirements "$d"
  done

########################################
# REQUIRED MODELS FOR NEW X-MODE TEMPLATE
########################################
# Verified from your new workflow/debug exports:
# - z_image_turbo_bf16.safetensors
# - qwen_3_4b.safetensors
# - ae.safetensors
# - Z-Image-Turbo-Fun-Controlnet-Union.safetensors
# - sam_vit_b_01ec64.pth

log "Downloading core X-Mode models"

# Z-Image Turbo DiT / UNET (place in diffusion_models; optional symlink into unet)
download_file \
  "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors?download=true" \
  "$MODELS_DIR/diffusion_models/z_image_turbo_bf16.safetensors" \
  1000
ln -sfn "$MODELS_DIR/diffusion_models/z_image_turbo_bf16.safetensors" "$MODELS_DIR/unet/z_image_turbo_bf16.safetensors"

# Z-Image text encoder used by the workflow
# Important: keep exact filename because workflow expects qwen_3_4b.safetensors.
download_file \
  "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors?download=true" \
  "$MODELS_DIR/text_encoders/qwen_3_4b.safetensors" \
  100

# Extra encoder often used by neighboring workflows; harmless if unused, useful for compatibility
if [[ ! -f "$MODELS_DIR/text_encoders/umt5-xxl-encoder-fp8-e4m3fn-scaled.safetensors" ]]; then
  warn "Optional WAN encoder not found; downloading for compatibility"
  download_file \
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors?download=true" \
    "$MODELS_DIR/text_encoders/umt5-xxl-encoder-fp8-e4m3fn-scaled.safetensors" \
    1000 || warn "Optional WAN encoder download failed; continuing"
fi

# VAE / autoencoder required by Z-Image family
if [[ ! -f "$MODELS_DIR/vae/ae.safetensors" ]]; then
  download_file \
    "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors?download=true" \
    "$MODELS_DIR/vae/ae.safetensors" \
    50
fi

# X-Mode control patch model - this was missing in your new template and is required
if [[ ! -f "$MODELS_DIR/controlnet/Z-Image-Turbo-Fun-Controlnet-Union.safetensors" ]]; then
  download_file \
    "https://huggingface.co/alibaba-pai/Z-Image-Turbo-Fun-Controlnet-Union/resolve/main/Z-Image-Turbo-Fun-Controlnet-Union.safetensors?download=true" \
    "$MODELS_DIR/controlnet/Z-Image-Turbo-Fun-Controlnet-Union.safetensors" \
    500
fi

# SAM model for FaceDetailer / Impact Pack
if [[ ! -f "$MODELS_DIR/sams/sam_vit_b_01ec64.pth" ]]; then
  download_file \
    "https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/sams/sam_vit_b_01ec64.pth?download=true" \
    "$MODELS_DIR/sams/sam_vit_b_01ec64.pth" \
    100
fi

########################################
# OPTIONAL DETECTOR MODELS FOR IMPACT PACK / DETAILERS
########################################
# These are not the main current blockers from your debug files,
# but missing bbox/segm detectors are a very common reason FaceDetailer chains break.
log "Downloading optional detector models for Impact Pack"

if [[ ! -f "$MODELS_DIR/ultralytics/bbox/face_yolov8m.pt" ]]; then
  download_file \
    "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt?download=true" \
    "$MODELS_DIR/ultralytics/bbox/face_yolov8m.pt" \
    10 || warn "Optional face_yolov8m download failed"
fi

if [[ ! -f "$MODELS_DIR/ultralytics/bbox/hand_yolov8s.pt" ]]; then
  download_file \
    "https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov8s.pt?download=true" \
    "$MODELS_DIR/ultralytics/bbox/hand_yolov8s.pt" \
    10 || warn "Optional hand_yolov8s download failed"
fi

if [[ ! -f "$MODELS_DIR/ultralytics/segm/person_yolov8m-seg.pt" ]]; then
  download_file \
    "https://huggingface.co/Bingsu/adetailer/resolve/main/person_yolov8m-seg.pt?download=true" \
    "$MODELS_DIR/ultralytics/segm/person_yolov8m-seg.pt" \
    10 || warn "Optional person_yolov8m-seg download failed"
fi

########################################
# USER LORA HANDLING
########################################
# We do NOT auto-download your private LoRAs here because they are user-specific.
# Workflow node "ВАША LORA" can stay empty until you upload one.
# If you want, you can add direct links below in the same style.

if [[ ! -f "$MODELS_DIR/loras/.keep" ]]; then
  touch "$MODELS_DIR/loras/.keep"
fi

########################################
# FINAL FIXES
########################################
# Some UIs/cache layers show stale lists. These touches help trigger refresh on restart.
find "$MODELS_DIR" -maxdepth 2 -type f | head -n 1 >/dev/null 2>&1 || true

echo "📥 Downloading Madeline LoRA..."
mkdir -p /workspace/ComfyUI/models/loras

download_if_missing() {
  local filepath="$1"
  local url="$2"
  if [ -f "$filepath" ]; then
    echo "✅ Exists: $filepath"
  else
    echo "⬇️ Downloading: $filepath"
    aria2c -x 8 -s 8 -k 1M --allow-overwrite=true -d "$(dirname "$filepath")" -o "$(basename "$filepath")" "$url"
  fi
}

download_if_missing \
  "/workspace/ComfyUI/models/loras/Madeline_data_set.safetensors" \
  "https://huggingface.co/Durdomcore/Maeline/resolve/main/Madeline_data_set.safetensors"

download_if_missing \
  "/workspace/ComfyUI/models/loras/Madeline_data_set_000003000.safetensors" \
  "https://huggingface.co/Durdomcore/Maeline/resolve/main/Madeline_data_set_000003000.safetensors"

print_summary
log "Done. Restart ComfyUI/container if model lists still look stale."
