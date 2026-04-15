#!/bin/bash
set -e
echo "🚀 Provisioning FULL WORKFLOW (Qwen3VLBasic + SeedVR2 + XMODE + detectors + SAM) started..."

apt-get update && apt-get install -y git wget curl aria2 python3-pip unzip

PIP="/venv/main/bin/pip"
COMFY="/workspace/ComfyUI"
MODELS="$COMFY/models"
NODES="$COMFY/custom_nodes"
WORKFLOWS="$COMFY/user/default/workflows"

echo "📦 Using pip: $PIP"

# ====================== CUSTOM NODES ======================
echo "📥 Клонируем custom nodes..."
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

echo "📦 Устанавливаем зависимости нод..."
$PIP install --upgrade --force-reinstall opencv-python opencv-python-headless
$PIP install -U ultralytics onnx onnxruntime-gpu segment-anything safetensors huggingface_hub || true

for dir in */; do
  if [ -f "$dir/requirements.txt" ]; then
    echo "→ Устанавливаем зависимости для $dir"
    $PIP install -r "$dir/requirements.txt" || true
  fi
done

# ====================== WORKFLOWS ======================
echo "📂 Копируем workflows..."
mkdir -p "$WORKFLOWS"
cp /workspace/provisioning/*.json "$WORKFLOWS/" 2>/dev/null || echo "⚠️ json workflows не найдены"

# ====================== MODEL DIRS ======================
echo "📁 Создаём папки моделей..."
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
  "$MODELS/LLM/Qwen3-VL-4B-Instruct"

cd "$MODELS"

# ====================== БАЗОВЫЕ МОДЕЛИ ======================
echo "📥 Скачиваем базовые модели..."

# VAE
aria2c -x 16 -s 16 --continue=true --dir="$MODELS/vae" --out=mo_vae.safetensors \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/vae.safetensors"

# compatibility alias for workflows expecting ae.safetensors
ln -sf "$MODELS/vae/mo_vae.safetensors" "$MODELS/vae/ae.safetensors"

# CLIP Vision
aria2c -x 16 -s 16 --continue=true --dir="$MODELS/clip_vision" --out=klip_vision.safetensors \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/klip_vision.safetensors"

# Text encoder
aria2c -x 16 -s 16 --continue=true --dir="$MODELS/text_encoders" --out=text_enc.safetensors \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/text_enc.safetensors"

# keep a copy/symlink in clip too for loaders that read from models/clip
ln -sf "$MODELS/text_encoders/text_enc.safetensors" "$MODELS/clip/text_enc.safetensors"

# compatibility alias for workflows expecting qwen_3_4b.safetensors
ln -sf "$MODELS/text_encoders/text_enc.safetensors" "$MODELS/clip/qwen_3_4b.safetensors"
ln -sf "$MODELS/text_encoders/text_enc.safetensors" "$MODELS/text_encoders/qwen_3_4b.safetensors"

# ====================== QWEN3-VL-4B-INSTRUCT ======================
echo "📥 Скачиваем Qwen3-VL-4B-Instruct..."
cd "$MODELS/LLM/Qwen3-VL-4B-Instruct"
aria2c -x 16 -s 16 --continue=true \
  "https://huggingface.co/Qwen/Qwen3-VL-4B-Instruct/resolve/main/config.json" \
  "https://huggingface.co/Qwen/Qwen3-VL-4B-Instruct/resolve/main/generation_config.json" \
  "https://huggingface.co/Qwen/Qwen3-VL-4B-Instruct/resolve/main/merges.txt" \
  "https://huggingface.co/Qwen/Qwen3-VL-4B-Instruct/resolve/main/tokenizer.json" \
  "https://huggingface.co/Qwen/Qwen3-VL-4B-Instruct/resolve/main/tokenizer_config.json" \
  "https://huggingface.co/Qwen/Qwen3-VL-4B-Instruct/resolve/main/vocab.json" \
  "https://huggingface.co/Qwen/Qwen3-VL-4B-Instruct/resolve/main/model-00001-of-00002.safetensors" \
  "https://huggingface.co/Qwen/Qwen3-VL-4B-Instruct/resolve/main/model-00002-of-00002.safetensors" \
  "https://huggingface.co/Qwen/Qwen3-VL-4B-Instruct/resolve/main/processor_config.json"

cd "$MODELS"

# ====================== XMODE / Z-IMAGE TURBO ======================
echo "📥 Скачиваем XMODE / Z-image turbo модели..."

# UNET / diffusion model expected by workflow
aria2c -x 16 -s 16 --continue=true --dir="$MODELS/diffusion_models" --out=z_image_turbo_bf16.safetensors \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/z_image_turbo_bf16.safetensors" || true

# keep alias in unet too for loaders that search there
ln -sf "$MODELS/diffusion_models/z_image_turbo_bf16.safetensors" "$MODELS/unet/z_image_turbo_bf16.safetensors" || true

# LoRA expected by workflow
aria2c -x 16 -s 16 --continue=true --dir="$MODELS/loras" --out=bueno-z_000001250.safetensors \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/bueno-z_000001250.safetensors" || true

# ====================== SAM MODELS ======================
echo "📥 Скачиваем SAM..."
wget -O "$MODELS/sams/sam_vit_b_01ec64.pth" \
  "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth" || true

# keep duplicate alias for loaders using models/sam
ln -sf "$MODELS/sams/sam_vit_b_01ec64.pth" "$MODELS/sam/sam_vit_b_01ec64.pth" || true

# ====================== ULTRALYTICS / BBOX DETECTORS ======================
echo "📥 Скачиваем bbox detectors..."

# face detector
wget -O "$MODELS/ultralytics/bbox/face_yolov8s.pt" \
  "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8s.pt" || true

# hand detector
wget -O "$MODELS/ultralytics/bbox/hand_yolov8s.pt" \
  "https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov8s.pt" || true

# Eyeful_v2-Paired fallback alias so workflow opens even if exact model is absent
# If later you have the exact Eyeful_v2-Paired.pt, just replace this alias with the real file.
ln -sf "$MODELS/ultralytics/bbox/face_yolov8s.pt" "$MODELS/ultralytics/bbox/Eyeful_v2-Paired.pt" || true

# ====================== WAN / DETECTION HELPERS (optional but useful) ======================
echo "📥 Скачиваем detection helpers..."
aria2c -x 16 -s 16 --continue=true --dir="$MODELS/detection" --out=yolov10m.onnx \
  "https://huggingface.co/Wan-AI/Wan2.2-Animate-14B/resolve/main/process_checkpoint/det/yolov10m.onnx" || true

aria2c -x 16 -s 16 --continue=true --dir="$MODELS/detection" --out=vitpose_h_wholebody_model.onnx \
  "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_model.onnx" || true

aria2c -x 16 -s 16 --continue=true --dir="$MODELS/detection" --out=vitpose_h_wholebody_data.bin \
  "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_data.bin" || true

echo ""
echo "✅ FULL WORKFLOW SETUP ГОТОВ"
echo ""
echo "Что добавлено:"
echo "  - text_enc.safetensors"
echo "  - alias qwen_3_4b.safetensors"
echo "  - mo_vae.safetensors"
echo "  - alias ae.safetensors"
echo "  - z_image_turbo_bf16.safetensors"
echo "  - bueno-z_000001250.safetensors"
echo "  - sam_vit_b_01ec64.pth"
echo "  - bbox/face_yolov8s.pt"
echo "  - bbox/hand_yolov8s.pt"
echo "  - fallback bbox/Eyeful_v2-Paired.pt"
echo ""
echo "Перезапусти ComfyUI полностью."
echo "После запуска открой workflow и проверь, что в нодах пропали пустые списки."
echo "🔥 Done."
