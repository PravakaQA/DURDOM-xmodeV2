#!/bin/bash
set -e
echo "🚀 Provisioning FULL WORKFLOW (Qwen3VLBasic + SeedVR2 + всё остальное) started..."
apt-get update && apt-get install -y git wget aria2 python3-pip unzip

PIP="/venv/main/bin/pip"
COMFY="/workspace/ComfyUI"
MODELS="$COMFY/models"
NODES="$COMFY/custom_nodes"
WORKFLOWS="$COMFY/user/default/workflows"

echo "📦 Using pip: $PIP"

# ====================== CUSTOM NODES ======================
echo "📥 Клонируем ВСЕ custom nodes..."
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
mkdir -p "$MODELS/diffusion_models" "$MODELS/vae" "$MODELS/text_encoders" "$MODELS/clip_vision" "$MODELS/loras" "$MODELS/detection" "$MODELS/LLM/Qwen3-VL-4B-Instruct"

cd "$MODELS"

# ====================== БАЗОВЫЕ МОДЕЛИ ======================
echo "📥 Скачиваем базовые модели..."
aria2c -x 16 -s 16 --continue=true --dir=vae --out=mo_vae.safetensors \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/vae.safetensors"

aria2c -x 16 -s 16 --continue=true --dir=clip_vision --out=klip_vision.safetensors \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/klip_vision.safetensors"

aria2c -x 16 -s 16 --continue=true --dir=text_encoders --out=text_enc.safetensors \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/text_enc.safetensors"

# ====================== QWEN3-VL-4B-INSTRUCT (автоматически) ======================
echo "📥 Скачиваем Qwen3-VL-4B-Instruct (это то, что нужно для Qwen3VLBasic)..."
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

echo ""
echo "✅ ВСЁ УСТАНОВЛЕНО АВТОМАТИЧЕСКИ!"
echo "Перезапусти ComfyUI полностью"
echo "Открой workflow → ноду Qwen3VLBasic"
echo "В ней выбери модель Qwen3-VL-4B-Instruct и нажми «Активировать»"
echo "Теперь всё должно работать без ошибок 🔥"
