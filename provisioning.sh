#!/bin/bash
echo "🚀 Provisioning XMODE (PHOTO) - FULL AUTO FIXED started..."
apt-get update && apt-get install -y git wget aria2 python3-pip unzip
cd /workspace/ComfyUI/custom_nodes
# ←←←←← ЭТО САМАЯ ВАЖНАЯ СТРОКА ←←←←←
PIP="/venv/main/bin/pip"
echo "📦 Используем venv pip: $PIP"
echo "📥 Клонируем ВСЕ custom nodes для XMODE (PHOTO)..."
git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git
git clone https://github.com/kijai/ComfyUI-WanAnimatePreprocess.git
git clone https://github.com/kijai/ComfyUI-KJNodes.git
git clone https://github.com/rgthree/rgthree-comfy.git
git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git
git clone https://github.com/teskor-hub/comfyui-teskors-utils.git
git clone https://github.com/PozzettiAndrea/ComfyUI-SAM3.git
git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git
git clone https://github.com/ClownsharkBatwing/ComfyUI-ClownsharK.git
git clone https://github.com/cubiq/ComfyUI_essentials.git
git clone https://github.com/LeonQ8/ComfyUI-Dynamic-Lora-Scheduler.git
git clone https://github.com/PGCRT/CRT-Nodes.git
echo "📦 Устанавливаем все зависимости в venv..."
# Сначала OpenCV (самая частая причина падения)
$PIP install --upgrade --force-reinstall opencv-python opencv-python-headless
# Теперь все requirements.txt из нод
for dir in */; do
  if [ -f "$dir/requirements.txt" ]; then
    echo "→ Устанавливаем зависимости для $dir"
    $PIP install -r "$dir/requirements.txt" || true
  fi
done
echo "📂 Копируем workflows (исправленный путь)..."
mkdir -p /workspace/ComfyUI/user/default/workflows
cp /workspace/provisioning/animator_v2_1_0.json /workspace/ComfyUI/user/default/workflows/animator_v2_1_0.json 2>/dev/null || echo "⚠️ animator_v2_1_0.json не найден в /workspace/provisioning/"
cp /workspace/provisioning/animator_v2_1_0_mask_mode.json /workspace/ComfyUI/user/default/workflows/animator_v2_1_0_mask_mode.json 2>/dev/null || echo "⚠️ animator_v2_1_0_mask_mode.json не найден в /workspace/provisioning/"

# ====================== МОДЕЛИ ======================
echo ""
echo "🚀 Скачиваем недостающие модели для XMODE (PHOTO) (WanVideo)..."
cd /workspace/ComfyUI/models
# Создаём папки, если их нет
mkdir -p diffusion_models vae clip_vision loras
echo "📥 1. Основная модель WanVideo → WanModel.safetensors (fp8, ~25-30 ГБ, отлично для твоей VRAM)"
aria2c -x 16 -s 16 --continue=true --dir=diffusion_models \
  --out=WanModel.safetensors \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1-I2V-14B-480P_fp8_e4m3fn.safetensors"
echo "📥 2. VAE → mo_vae.safetensors"
aria2c -x 16 -s 16 --continue=true --dir=vae \
  --out=mo_vae.safetensors \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors"
echo "📥 3. CLIP Vision → klip_vision.safetensors"
aria2c -x 16 -s 16 --continue=true --dir=clip_vision \
  --out=klip_vision.safetensors \
  "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors"

# LoRA (они используются в твоём workflow)
echo ""
echo "📌 Скачиваем LoRA (wan_reworked, WanPusa, WanFun.reworked)..."
aria2c -x 16 -s 16 --continue=true --dir=loras \
  --out=wan_reworked.safetensors \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/loras/wan_reworked.safetensors"
aria2c -x 16 -s 16 --continue=true --dir=loras \
  --out=WanPusa.safetensors \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/loras/WanPusa.safetensors"
aria2c -x 16 -s 16 --continue=true --dir=loras \
  --out=WanFun.reworked.safetensors \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/loras/WanFun.reworked.safetensors"

echo ""
echo "✅ XMODE (PHOTO) ПОЛНОСТЬЮ ГОТОВ!"
echo "Workflows: /workspace/ComfyUI/user/default/workflows/"
echo "Модели: diffusion_models, vae, clip_vision, loras"
echo "После перезапуска ComfyUI зайди в Manager → Check Missing (должно быть чисто)"
echo "Готово к запуску твоего workflow! 🔥"
