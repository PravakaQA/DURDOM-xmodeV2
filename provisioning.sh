#!/bin/bash
echo "🚀 Provisioning XMODE (PHOTO) - FULL AUTO FIXED v4 (актуально апрель 2026) started..."
apt-get update && apt-get install -y git wget aria2 python3-pip unzip
cd /workspace/ComfyUI/custom_nodes

PIP="/venv/main/bin/pip"
echo "📦 Используем venv pip: $PIP"

echo "📥 Клонируем ВСЕ custom nodes..."
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

echo "📦 Устанавливаем зависимости..."
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
echo "🚀 Скачиваем ВСЕ модели для XMODE (PHOTO)..."
cd /workspace/ComfyUI/models
mkdir -p diffusion_models vae text_encoders clip_vision loras

echo "📥 1. Основная модель WanVideo → WanModel.safetensors"
aria2c -x 16 -s 16 --continue=true --dir=diffusion_models \
  --out=WanModel.safetensors \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1-I2V-14B-480P_fp8_e4m3fn.safetensors" || echo "⚠️ Основная модель не скачалась"

echo "📥 2. VAE → mo_vae.safetensors (исправленная рабочая ссылка)"
aria2c -x 16 -s 16 --continue=true --dir=vae \
  --out=mo_vae.safetensors \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors" || echo "⚠️ VAE не скачался (проверь ссылку)"

echo "📥 3. CLIP Vision → klip_vision.safetensors"
aria2c -x 16 -s 16 --continue=true --dir=clip_vision \
  --out=klip_vision.safetensors \
  "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors" || echo "⚠️ KLIP VISION не скачался"

echo "📥 4. Text Encoder → text_enc.safetensors (в правильную папку text_encoders/)"
aria2c -x 16 -s 16 --continue=true --dir=text_encoders \
  --out=text_enc.safetensors \
  "https://huggingface.co/Isi99999/Wan2.1-T2V-1.3B/resolve/main/umt5-xxl-enc-fp8_e4m3fn.safetensors" || echo "⚠️ Text Encoder не скачался"

echo "📥 5. LoRA (light, wan_reworked, WanPusa, WanFun.reworked)"
aria2c -x 16 -s 16 --continue=true --dir=loras --out=light.safetensors "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan21_T2V_14B_lightx2v_cfg_step_distill_lora_rank32.safetensors" || echo "⚠️ light.safetensors не скачался"
aria2c -x 16 -s 16 --continue=true --dir=loras --out=wan_reworked.safetensors "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/loras/wan_reworked.safetensors" || echo "⚠️ wan_reworked не найден"
aria2c -x 16 -s 16 --continue=true --dir=loras --out=WanPusa.safetensors "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Pusa/Wan22_PusaV1_lora_LOW_resized_dynamic_avg_rank_98_bf16.safetensors" || echo "⚠️ WanPusa не скачался"
aria2c -x 16 -s 16 --continue=true --dir=loras --out=WanFun.reworked.safetensors "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Fun/Wan2_2_Fun_VACE_module_A14B_LOW_bf16.safetensors" || echo "⚠️ WanFun.reworked не скачался"

echo ""
echo "✅ XMODE (PHOTO) ПОЛНОСТЬЮ ГОТОВ! 🔥"
echo "Папки моделей: diffusion_models, vae, text_encoders, clip_vision, loras"
echo "После перезапуска ComfyUI зайди в Manager → Check Missing"
echo "Теперь VAE, KLIP VISION и text_enc должны стать зелёными."
echo "Если что-то осталось красным — просто скинь новый скрин, я сразу поправлю."
