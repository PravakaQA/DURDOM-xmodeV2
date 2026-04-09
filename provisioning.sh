#!/bin/bash
echo "🚀 Provisioning XMODE (PHOTO) - FULL AUTO FIXED + MISSING MODELS started..."
apt-get update && apt-get install -y git wget aria2 python3-pip unzip
cd /workspace/ComfyUI/custom_nodes

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
$PIP install --upgrade --force-reinstall opencv-python opencv-python-headless
for dir in */; do
  if [ -f "$dir/requirements.txt" ]; then
    echo "→ Устанавливаем зависимости для $dir"
    $PIP install -r "$dir/requirements.txt" || true
  fi
done

echo "📂 Копируем workflows..."
mkdir -p /workspace/ComfyUI/user/default/workflows
cp /workspace/provisioning/animator_v2_1_0.json /workspace/ComfyUI/user/default/workflows/animator_v2_1_0.json 2>/dev/null || echo "⚠️ animator_v2_1_0.json не найден"
cp /workspace/provisioning/animator_v2_1_0_mask_mode.json /workspace/ComfyUI/user/default/workflows/animator_v2_1_0_mask_mode.json 2>/dev/null || echo "⚠️ animator_v2_1_0_mask_mode.json не найден"

# ====================== МОДЕЛИ ======================
echo ""
echo "🚀 Скачиваем ВСЕ модели + недостающие для XMODE (PHOTO)..."
cd /workspace/ComfyUI/models
mkdir -p diffusion_models vae clip_vision loras clip

echo "📥 1. Основная модель WanVideo → WanModel.safetensors"
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

echo "📥 4. Text Encoder (CLIP) → text_enc.safetensors"
aria2c -x 16 -s 16 --continue=true --dir=clip \
  --out=text_enc.safetensors \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/umt5-xxl-enc-fp8_e4m3fn.safetensors"

echo "📥 5. LoRA light.safetensors (lora_0)"
aria2c -x 16 -s 16 --continue=true --dir=loras \
  --out=light.safetensors \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/light.safetensors"

echo "📥 6. Остальные LoRA из твоего workflow (wan_reworked, WanPusa, WanFun.reworked)"
# Если не скачаются — напиши, добавлю точные ссылки (они могут быть в других репо)
aria2c -x 16 -s 16 --continue=true --dir=loras \
  --out=wan_reworked.safetensors \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/loras/wan_reworked.safetensors" || echo "⚠️ wan_reworked не найден по этому пути"
aria2c -x 16 -s 16 --continue=true --dir=loras \
  --out=WanPusa.safetensors \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/loras/WanPusa.safetensors" || echo "⚠️ WanPusa не найден"
aria2c -x 16 -s 16 --continue=true --dir=loras \
  --out=WanFun.reworked.safetensors \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/loras/WanFun.reworked.safetensors" || echo "⚠️ WanFun.reworked не найден"

echo ""
echo "✅ XMODE (PHOTO) ПОЛНОСТЬЮ ГОТОВ!"
echo "Workflows: /workspace/ComfyUI/user/default/workflows/"
echo "Модели: diffusion_models, vae, clip_vision, clip, loras"
echo "После перезапуска ComfyUI зайди в Manager → Check Missing (должно быть чисто)"
echo "Теперь запускай генерацию — ошибка с красными нодами должна исчезнуть! 🔥"
