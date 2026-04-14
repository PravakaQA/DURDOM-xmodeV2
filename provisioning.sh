#!/bin/bash
set -e
echo "🚀 Provisioning NEW WORKFLOW (Qwen3VLBasic + SeedVR2 + ResolutionMaster) started..."
apt-get update && apt-get install -y git wget aria2 python3-pip unzip
PIP="/venv/main/bin/pip"
COMFY="/workspace/ComfyUI"
MODELS="$COMFY/models"
NODES="$COMFY/custom_nodes"
WORKFLOWS="$COMFY/user/default/workflows"

echo "📦 Using pip: $PIP"

# ====================== CUSTOM NODES (все недостающие + предыдущие) ======================
echo "📥 Cloning ALL custom nodes..."
cd "$NODES"
git clone https://github.com/ZhiHui6/zhihui_nodes_comfyui.git || true          # ← Qwen3VLBasic
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
for dir in */; do
  if [ -f "$dir/requirements.txt" ]; then
    echo "→ Installing requirements for $dir"
    $PIP install -r "$dir/requirements.txt" || true
  fi
done

# ====================== WORKFLOWS ======================
echo "📂 Copying workflows..."
mkdir -p "$WORKFLOWS"
cp /workspace/provisioning/*.json "$WORKFLOWS/" 2>/dev/null || echo "⚠️ json workflows не найдены"

# ====================== MODEL DIRS ======================
echo "📁 Creating model directories..."
mkdir -p "$MODELS/diffusion_models" "$MODELS/vae" "$MODELS/text_encoders" "$MODELS/clip_vision" "$MODELS/loras" "$MODELS/detection"

cd "$MODELS"

# ====================== БАЗОВЫЕ МОДЕЛИ ======================
echo "📥 Скачиваем базовые модели..."
aria2c -x 16 -s 16 --continue=true --dir=vae --out=mo_vae.safetensors \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/vae.safetensors" || true

aria2c -x 16 -s 16 --continue=true --dir=clip_vision --out=klip_vision.safetensors \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/klip_vision.safetensors" || true

aria2c -x 16 -s 16 --continue=true --dir=text_encoders --out=text_enc.safetensors \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/text_enc.safetensors" || true

echo ""
echo "✅ СКРИПТ ЗАВЕРШЁН!"
echo "Теперь полностью перезапусти ComfyUI"
echo "Зайди в Manager → Check Missing → Install Missing Nodes"
echo "Qwen3VLBasic и все остальные ноды должны установиться автоматически."
echo "Если что-то останется — кинь скрин, сразу добавлю."
