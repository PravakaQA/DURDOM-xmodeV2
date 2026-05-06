#!/bin/bash
set -e

echo "🚀 Provisioning X-MODE FIXED started..."

apt-get update && apt-get install -y git wget curl aria2 python3-pip unzip

PIP="/venv/main/bin/pip"
PY="/venv/main/bin/python"
COMFY="/workspace/ComfyUI"
MODELS="$COMFY/models"
NODES="$COMFY/custom_nodes"
WORKFLOWS="$COMFY/user/default/workflows"

echo "📦 Using pip: $PIP"
echo "🐍 Using python: $PY"

# ====================== HELPERS ======================
aria_dl() {
  local url="$1"
  local dir="$2"
  local out="$3"

  mkdir -p "$dir"

  if [ -f "$dir/$out" ]; then
    echo "✅ Exists: $dir/$out"
    return 0
  fi

  echo "📥 Downloading: $out"
  aria2c \
    -x 16 -s 16 -k 1M \
    --continue=true \
    --allow-overwrite=true \
    --auto-file-renaming=false \
    --retry-wait=5 \
    --max-tries=0 \
    --timeout=60 \
    --connect-timeout=60 \
    --summary-interval=10 \
    --dir="$dir" \
    --out="$out" \
    "$url"
}

safe_link() {
  local src="$1"
  local dst="$2"
  mkdir -p "$(dirname "$dst")"
  ln -sfn "$src" "$dst" || true
}

safe_copy_if_missing() {
  local src="$1"
  local dst="$2"

  if [ -f "$src" ] && [ ! -f "$dst" ]; then
    cp -f "$src" "$dst" || true
  fi
}

# ====================== CUSTOM NODES ======================
echo "📥 Cloning custom nodes..."
mkdir -p "$NODES"
cd "$NODES"

git clone https://github.com/ZhiHui6/zhihui_nodes_comfyui.git || true
git clone https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git || true
git clone https://github.com/numz/ComfyUI-SeedVR2_VideoUpscaler.git || true
git clone https://github.com/Azornes/Comfyui-Resolution-Master.git || true
git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git || true
git clone https://github.com/chrisgoringe/cg-use-everywhere.git || true
git clone https://github.com/ClownsharkBatwing/RES4LYF.git || true
git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git || true
git clone https://github.com/kijai/ComfyUI-WanAnimatePreprocess.git || true
git clone https://github.com/kijai/ComfyUI-KJNodes.git || true
git clone https://github.com/rgthree/rgthree-comfy.git || true
git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git || true
git clone https://github.com/teskor-hub/comfyui-teskors-utils.git || true
git clone https://github.com/PozzettiAndrea/ComfyUI-SAM3.git || true
git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git || true
git clone https://github.com/ClownsharkBatwing/ComfyUI-ClownsharK.git || true
git clone https://github.com/cubiq/ComfyUI_essentials.git || true
git clone https://github.com/LeonQ8/ComfyUI-Dynamic-Lora-Scheduler.git || true
git clone https://github.com/PGCRT/CRT-Nodes.git || true

echo "📦 Installing node requirements..."
$PIP install --upgrade --force-reinstall opencv-python opencv-python-headless || true
$PIP install -U ultralytics onnx onnxruntime-gpu segment-anything safetensors huggingface_hub bitsandbytes transformers accelerate sentencepiece modelscope || true

for dir in */; do
  if [ -f "$dir/requirements.txt" ]; then
    echo "→ Installing requirements for $dir"
    $PIP install -r "$dir/requirements.txt" || true
  fi
done

# ====================== WORKFLOWS ======================
echo "📂 Copying workflows..."
mkdir -p "$WORKFLOWS"
cp /workspace/provisioning/*.json "$WORKFLOWS/" 2>/dev/null || echo "⚠️ json workflows not found"

# ====================== MODEL DIRS ======================
echo "📁 Creating model directories..."
mkdir -p \
  "$MODELS/diffusion_models" \
  "$MODELS/unet" \
  "$MODELS/vae" \
  "$MODELS/text_encoders" \
  "$MODELS/clip" \
  "$MODELS/clip_vision" \
  "$MODELS/loras" \
  "$MODELS/detection" \
  "$MODELS/ultralytics/bbox" \
  "$MODELS/sams" \
  "$MODELS/sam" \
  "$MODELS/LLM"

# ====================== BASE MODELS ======================
echo "📥 Downloading base models..."

aria_dl \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/vae.safetensors" \
  "$MODELS/vae" \
  "mo_vae.safetensors"
safe_link "$MODELS/vae/mo_vae.safetensors" "$MODELS/vae/ae.safetensors"

aria_dl \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/klip_vision.safetensors" \
  "$MODELS/clip_vision" \
  "klip_vision.safetensors"

aria_dl \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/text_enc.safetensors" \
  "$MODELS/text_encoders" \
  "text_enc.safetensors"

safe_link "$MODELS/text_encoders/text_enc.safetensors" "$MODELS/clip/text_enc.safetensors"

# ====================== TEXT ENCODER FIXES ======================
echo "📥 Creating text encoder aliases..."

# основной фикс для CLIPLoader / workflow
safe_copy_if_missing \
  "$MODELS/text_encoders/text_enc.safetensors" \
  "$MODELS/text_encoders/qwen_3_4b.safetensors"

safe_link \
  "$MODELS/text_encoders/qwen_3_4b.safetensors" \
  "$MODELS/clip/qwen_3_4b.safetensors"

# дополнительные alias'ы на случай разных названий в workflow
safe_link \
  "$MODELS/text_encoders/text_enc.safetensors" \
  "$MODELS/text_encoders/qwen2.5vl.safetensors"

safe_link \
  "$MODELS/text_encoders/text_enc.safetensors" \
  "$MODELS/text_encoders/qwen_2_5_vl_7b_fp8_scaled.safetensors"

safe_link \
  "$MODELS/text_encoders/text_enc.safetensors" \
  "$MODELS/clip/qwen2.5vl.safetensors"

safe_link \
  "$MODELS/text_encoders/text_enc.safetensors" \
  "$MODELS/clip/qwen_2_5_vl_7b_fp8_scaled.safetensors"

# если у тебя когда-то появится отдельный umt5 файл в OFMHUB, можно просто заменить ссылку ниже.
# Сейчас специально НЕ качаем огромный медленный shard-based snapshot.
if [ ! -f "$MODELS/text_encoders/umt5-xxl-encoder-fp8-e4m3fn-scaled.safetensors" ]; then
  echo "ℹ️ umt5-xxl-encoder-fp8-e4m3fn-scaled.safetensors not found. Skipping direct download on purpose."
fi

# ====================== ADDITIONAL MODELS ======================
echo "📥 Downloading additional models..."

aria_dl \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/z_image_turbo_bf16.safetensors" \
  "$MODELS/diffusion_models" \
  "z_image_turbo_bf16.safetensors"

safe_link \
  "$MODELS/diffusion_models/z_image_turbo_bf16.safetensors" \
  "$MODELS/unet/z_image_turbo_bf16.safetensors"

aria_dl \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/bueno-z_000001250.safetensors" \
  "$MODELS/loras" \
  "bueno-z_000001250.safetensors"

if [ ! -f "$MODELS/sams/sam_vit_b_01ec64.pth" ]; then
  wget -O "$MODELS/sams/sam_vit_b_01ec64.pth" \
    "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth" || true
fi
safe_link "$MODELS/sams/sam_vit_b_01ec64.pth" "$MODELS/sam/sam_vit_b_01ec64.pth"

if [ ! -f "$MODELS/ultralytics/bbox/face_yolov8s.pt" ]; then
  wget -O "$MODELS/ultralytics/bbox/face_yolov8s.pt" \
    "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8s.pt" || true
fi

if [ ! -f "$MODELS/ultralytics/bbox/hand_yolov8s.pt" ]; then
  wget -O "$MODELS/ultralytics/bbox/hand_yolov8s.pt" \
    "https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov8s.pt" || true
fi

safe_link \
  "$MODELS/ultralytics/bbox/face_yolov8s.pt" \
  "$MODELS/ultralytics/bbox/Eyeful_v2-Paired.pt"

# ====================== FINAL CHECKS ======================
echo ""
echo "==== FINAL MODEL CHECK ===="
ls -lah "$MODELS/text_encoders" || true
ls -lah "$MODELS/clip" || true
ls -lah "$MODELS/diffusion_models" || true
ls -lah "$MODELS/vae" || true
ls -lah "$MODELS/clip_vision" || true
ls -lah "$MODELS/loras" || true

echo ""
echo "✅ X-MODE SETUP READY"
echo "Перезапусти ComfyUI полностью."
echo "Если workflow просит qwen_3_4b.safetensors — он уже создан."
echo "Медленный ModelScope/Qwen3-VL-4B-Instruct блок убран."
echo "🔥 Готово"
