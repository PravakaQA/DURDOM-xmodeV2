#!/bin/bash
set -e
echo "🚀 Provisioning FULL WORKFLOW FIXED started..."
apt-get update && apt-get install -y git wget curl aria2 python3-pip unzip

PIP="/venv/main/bin/pip"
PY="/venv/main/bin/python"
COMFY="/workspace/ComfyUI"
MODELS="$COMFY/models"
NODES="$COMFY/custom_nodes"
WORKFLOWS="$COMFY/user/default/workflows"

MS_CACHE_ROOT="/root/.cache/modelscope"
WS_CACHE_ROOT="/workspace/.cache/modelscope"

echo "📦 Using pip: $PIP"
echo "🐍 Using python: $PY"

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
$PIP install --upgrade --force-reinstall opencv-python opencv-python-headless
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
mkdir -p "$MODELS/diffusion_models" "$MODELS/unet" "$MODELS/vae" "$MODELS/text_encoders" "$MODELS/clip" "$MODELS/clip_vision" "$MODELS/loras" "$MODELS/detection" "$MODELS/ultralytics/bbox" "$MODELS/sams" "$MODELS/sam" "$MODELS/LLM"

mkdir -p "$MS_CACHE_ROOT" "$WS_CACHE_ROOT"
ln -sfn "$MS_CACHE_ROOT" "$WS_CACHE_ROOT" || true

cd "$MODELS"

# ====================== BASE MODELS ======================
echo "📥 Downloading base models..."
aria2c -x 16 -s 16 --continue=true --dir="$MODELS/vae" --out=mo_vae.safetensors "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/vae.safetensors"
ln -sf "$MODELS/vae/mo_vae.safetensors" "$MODELS/vae/ae.safetensors" || true

aria2c -x 16 -s 16 --continue=true --dir="$MODELS/clip_vision" --out=klip_vision.safetensors "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/klip_vision.safetensors"

aria2c -x 16 -s 16 --continue=true --dir="$MODELS/text_encoders" --out=text_enc.safetensors "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/text_enc.safetensors"
ln -sf "$MODELS/text_encoders/text_enc.safetensors" "$MODELS/clip/text_enc.safetensors" || true

# ====================== QWEN CLIP FIX ======================
echo "📥 Creating qwen_3_4b.safetensors for CLIPLoader..."
cp "$MODELS/text_encoders/text_enc.safetensors" "$MODELS/text_encoders/qwen_3_4b.safetensors" 2>/dev/null || echo "⚠️ Не удалось создать qwen_3_4b.safetensors"
ln -sf "$MODELS/text_encoders/qwen_3_4b.safetensors" "$MODELS/clip/qwen_3_4b.safetensors" || true

# ====================== QWEN3-VL-4B-INSTRUCT ======================
echo "📥 Downloading Qwen3-VL-4B-Instruct via ModelScope..."
export MODELSCOPE_CACHE="$MS_CACHE_ROOT"
$PY - <<'PY'
import os
from modelscope import snapshot_download
cache_root = os.environ["MODELSCOPE_CACHE"]
model_dir = snapshot_download(model_id="Qwen/Qwen3-VL-4B-Instruct", cache_dir=cache_root)
print(f"✅ ModelScope downloaded to: {model_dir}")
PY

if [ -d "$MS_CACHE_ROOT/hub/Qwen/Qwen3-VL-4B-Instruct" ]; then
  ln -sfn "$MS_CACHE_ROOT/hub/Qwen/Qwen3-VL-4B-Instruct" "$MODELS/LLM/Qwen3-VL-4B-Instruct"
fi

# ====================== ДРУГИЕ МОДЕЛИ ======================
echo "📥 Downloading additional models..."
aria2c -x 16 -s 16 --continue=true --dir="$MODELS/diffusion_models" --out=z_image_turbo_bf16.safetensors "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/z_image_turbo_bf16.safetensors" || true
ln -sf "$MODELS/diffusion_models/z_image_turbo_bf16.safetensors" "$MODELS/unet/z_image_turbo_bf16.safetensors" || true

aria2c -x 16 -s 16 --continue=true --dir="$MODELS/loras" --out=bueno-z_000001250.safetensors "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/bueno-z_000001250.safetensors" || true

wget -O "$MODELS/sams/sam_vit_b_01ec64.pth" "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth" || true
ln -sf "$MODELS/sams/sam_vit_b_01ec64.pth" "$MODELS/sam/sam_vit_b_01ec64.pth" || true

wget -O "$MODELS/ultralytics/bbox/face_yolov8s.pt" "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8s.pt" || true
wget -O "$MODELS/ultralytics/bbox/hand_yolov8s.pt" "https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov8s.pt" || true
ln -sf "$MODELS/ultralytics/bbox/face_yolov8s.pt" "$MODELS/ultralytics/bbox/Eyeful_v2-Paired.pt" || true

echo ""
echo "✅ FULL WORKFLOW SETUP READY"
echo "Перезапусти ComfyUI полностью"
echo "В CLIPLoader обязательно поставь clip_name = text_enc.safetensors"
echo "В Qwen3VLBasic выбери Qwen3-VL-4B-Instruct и нажми Активировать"
echo "🔥 Готово"
