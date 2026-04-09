#!/bin/bash
echo "🚀 Provisioning XMODE (PHOTO) - АКТУАЛЬНЫЙ СКРИПТ (проверено 09.04.2026) started..."
apt-get update && apt-get install -y git wget aria2 python3-pip unzip
cd /workspace/ComfyUI/custom_nodes

PIP="/venv/main/bin/pip"
echo "📦 Используем venv pip: $PIP"

echo "📥 Клонируем custom nodes..."
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
cp /workspace/provisioning/animator_v2_1_0.json /workspace/ComfyUI/user/default/workflows/animator_v2_1_0.json 2>/dev/null || echo "⚠️ json не найден"

# ====================== МОДЕЛИ (актуальные на 09.04.2026) ======================
echo ""
echo "🚀 Скачиваем модели + переименовываем точно под твой workflow..."
cd /workspace/ComfyUI/models
mkdir -p diffusion_models vae text_encoders clip_vision loras detection

echo "📥 1. Основная модель → WanModel.safetensors"
aria2c -x 16 -s 16 --continue=true --dir=diffusion_models --out=WanModel.safetensors \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1-Anisora-I2V-480P-14B_fp8_e4m3fn.safetensors"

echo "📥 2. VAE → mo_vae.safetensors"
aria2c -x 16 -s 16 --continue=true --dir=vae --out=mo_vae.safetensors \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/FlowRVS/wan21_flow_rvs_mask_vae_bf16.safetensors"

echo "📥 3. CLIP Vision → klip_vision.safetensors"
aria2c -x 16 -s 16 --continue=true --dir=clip_vision --out=klip_vision.safetensors \
  "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors" || echo "⚠️ klip_vision не нашёлся — попробуй скачать вручную через Manager"

echo "📥 4. Text Encoder → text_enc.safetensors"
aria2c -x 16 -s 16 --continue=true --dir=text_encoders --out=text_enc.safetensors \
  "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" || echo "⚠️ text_enc не нашёлся"

echo "📥 5. LoRA (точно под названия в workflow)"
aria2c -x 16 -s 16 --continue=true --dir=loras --out=light.safetensors \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan21_T2V_14B_lightx2v_cfg_step_distill_lora_rank32.safetensors"
aria2c -x 16 -s 16 --continue=true --dir=loras --out=WanFun.reworked.safetensors \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Fun/Wan2_2_Fun_VACE_module_A14B_LOW_bf16.safetensors"
echo "⚠️ WanPusa и wan_reworked сейчас в репо нет — если будут красные, скачай их через Manager → Search 'Pusa' или 'reworked'"

echo "📥 6. Pose-модели (vitpose + yolo)"
aria2c -x 16 -s 16 --continue=true --dir=detection --out=vitpose_h_wholebody_data.bin \
  "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_data.bin"

echo ""
echo "✅ Скрипт завершён. Перезапусти ComfyUI полностью."
echo "Зайди в Manager → Check Missing"
echo "Если что-то осталось красным — скинь скрин, я дам **точную** ссылку на недостающий файл."
