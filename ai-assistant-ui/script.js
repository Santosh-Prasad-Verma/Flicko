// ══════════════════════════════════════════
// AURA AI Assistant - Interactive Engine
// ══════════════════════════════════════════

document.addEventListener('DOMContentLoaded', () => {
  // DOM Elements
  const btnGrid = document.getElementById('btn-grid');
  const btnFlow = document.getElementById('btn-flow');
  const showcaseGrid = document.getElementById('showcase-grid');
  
  const frameOnboarding = document.getElementById('frame-onboarding');
  const frameChat = document.getElementById('frame-chat');
  const frameSettings = document.getElementById('frame-settings');
  
  const btnGetStarted = document.getElementById('btn-get-started');
  const btnSettingsBack = document.getElementById('btn-settings-back');
  const btnsBackOnboarding = document.querySelectorAll('.btn-back-onboarding');
  const btnHamburger = document.querySelector('.btn-hamburger');
  const btnRefresh = document.getElementById('btn-refresh');
  const btnMic = document.getElementById('btn-mic');
  const toggleLightMode = document.getElementById('toggle-light-mode');
  const speechText = document.getElementById('speech-text');
  const toast = document.getElementById('toast');
  const toastMessage = document.getElementById('toast-message');

  // State Variables
  let currentFlowScreenIndex = 0; // 0: Onboarding, 1: Chat, 2: Settings
  let isFlowMode = false;
  let isListening = true;
  let currentPromptIndex = 0;
  
  const prompts = [
    "give me color recommendation for finance application",
    "explain quantum computing in 3 simple sentences",
    "draft a pitch deck outline for a cyber coffee brand",
    "what are the top 3 UI/UX design trends for 2026?",
    "help me debug a cross-origin resource sharing (CORS) error"
  ];

  // ── VIEW MODE CONTROLS ──
  btnGrid.addEventListener('click', () => {
    isFlowMode = false;
    btnGrid.classList.add('active');
    btnFlow.classList.remove('active');
    showcaseGrid.classList.remove('flow-mode');
    
    // Reset classes
    document.querySelectorAll('.device-frame').forEach(frame => {
      frame.className = 'device-frame';
    });
  });

  btnFlow.addEventListener('click', () => {
    isFlowMode = true;
    btnFlow.classList.add('active');
    btnGrid.classList.remove('active');
    showcaseGrid.classList.add('flow-mode');
    
    updateFlowView();
  });

  function updateFlowView() {
    if (!isFlowMode) return;
    
    const frames = [frameOnboarding, frameChat, frameSettings];
    
    frames.forEach((frame, idx) => {
      frame.className = 'device-frame';
      if (idx === currentFlowScreenIndex) {
        frame.classList.add('active');
      } else if (idx === currentFlowScreenIndex - 1) {
        frame.classList.add('prev');
      } else if (idx === currentFlowScreenIndex + 1) {
        frame.classList.add('next');
      }
    });
  }

  // ── FLOW TRANSITIONS ──
  btnGetStarted.addEventListener('click', () => {
    if (isFlowMode) {
      currentFlowScreenIndex = 1; // Go to Chat
      updateFlowView();
    } else {
      highlightFrame(frameChat);
    }
    showToast("Opening Chat Interface");
  });

  btnHamburger.addEventListener('click', () => {
    if (isFlowMode) {
      currentFlowScreenIndex = 2; // Go to Settings
      updateFlowView();
    } else {
      highlightFrame(frameSettings);
    }
    showToast("Opening Settings");
  });

  btnSettingsBack.addEventListener('click', () => {
    if (isFlowMode) {
      currentFlowScreenIndex = 1; // Go to Chat
      updateFlowView();
    } else {
      highlightFrame(frameChat);
    }
    showToast("Back to Chat");
  });

  btnsBackOnboarding.forEach(btn => {
    btn.addEventListener('click', () => {
      if (isFlowMode) {
        currentFlowScreenIndex = 0; // Go to Onboarding
        updateFlowView();
      } else {
        highlightFrame(frameOnboarding);
      }
      showToast("Back to Home");
    });
  });

  function highlightFrame(frame) {
    frame.style.transform = 'translateY(-15px) scale(1.03)';
    frame.style.boxShadow = '0 30px 60px rgba(123, 79, 255, 0.4)';
    setTimeout(() => {
      frame.style.transform = '';
      frame.style.boxShadow = '';
    }, 600);
  }

  // ── SOUNDWAVE CANVAS ANIMATION ──
  const canvas = document.getElementById('waveform-canvas');
  const ctx = canvas.getContext('2d');
  let animationId;

  // Set canvas dimensions based on container
  function resizeCanvas() {
    canvas.width = canvas.parentElement.clientWidth;
    canvas.height = canvas.parentElement.clientHeight;
  }
  resizeCanvas();
  window.addEventListener('resize', resizeCanvas);

  // Audio wave configurations
  const waves = [
    { amplitude: 35, frequency: 0.015, speed: 0.15, color: 'rgba(0, 240, 255, 0.7)' },  // Cyan primary
    { amplitude: 20, frequency: 0.025, speed: -0.1, color: 'rgba(123, 79, 255, 0.5)' }, // Purple overlay
    { amplitude: 10, frequency: 0.04, speed: 0.22, color: 'rgba(255, 0, 245, 0.3)' }    // Pink background highlight
  ];

  let offset = 0;

  function animateWave() {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    const middleY = canvas.height / 2;

    waves.forEach((wave, idx) => {
      ctx.beginPath();
      ctx.strokeStyle = wave.color;
      // Soften line width for background layers
      ctx.lineWidth = idx === 0 ? 3.5 : 2;
      ctx.lineCap = 'round';

      // Draw EKG / Sine-like wave
      for (let x = 0; x < canvas.width; x++) {
        // Multiplier to create a pinch effect at the left and right edges (envelope)
        const envelope = Math.sin((x / canvas.width) * Math.PI);
        
        // Modulate amplitude based on state (pulsing if listening, flat idle if paused)
        const currentAmp = isListening 
          ? wave.amplitude * (1 + 0.3 * Math.sin(offset * 0.05 + idx)) * envelope
          : 3 * envelope; // Soft idle wave

        const y = middleY + Math.sin(x * wave.frequency + offset * wave.speed) * currentAmp;
        
        if (x === 0) {
          ctx.moveTo(x, y);
        } else {
          ctx.lineTo(x, y);
        }
      }
      ctx.stroke();
    });

    offset += 0.8;
    animationId = requestAnimationFrame(animateWave);
  }
  animateWave();

  // ── TOGGLE MICROPHONE (LISTENING) ──
  btnMic.addEventListener('click', () => {
    isListening = !isListening;
    if (isListening) {
      btnMic.classList.add('active');
      btnMic.classList.remove('muted');
      document.querySelector('.pulse-container').style.opacity = '1';
      document.querySelector('.listening-text').textContent = "I'm listening...";
      showToast("Listening Resume");
    } else {
      btnMic.classList.remove('active');
      btnMic.classList.add('muted');
      document.querySelector('.pulse-container').style.opacity = '0.3';
      document.querySelector('.listening-text').textContent = "Tap Mic to Talk";
      showToast("Listening Paused");
    }
  });

  // ── CYCLING PROMPTS (REFRESH) ──
  btnRefresh.addEventListener('click', () => {
    currentPromptIndex = (currentPromptIndex + 1) % prompts.length;
    const text = prompts[currentPromptIndex];
    
    // Smooth fade & type animation
    speechText.style.opacity = '0';
    setTimeout(() => {
      speechText.textContent = text;
      speechText.style.opacity = '1';
    }, 300);
    
    // Temporarily trigger wave pulse spike
    if (isListening) {
      waves.forEach(w => w.amplitude *= 1.6);
      setTimeout(() => {
        waves[0].amplitude = 35;
        waves[1].amplitude = 20;
        waves[2].amplitude = 10;
      }, 800);
    }
    
    showToast("Prompts Cycled");
  });

  // ── TOGGLE LIGHT MODE ──
  toggleLightMode.addEventListener('click', () => {
    toggleLightMode.classList.toggle('active');
    const isActive = toggleLightMode.classList.contains('active');
    
    if (isActive) {
      showToast("Light Mood Activated");
      // Mute device colors subtly to reflect simulated light theme (just inside mockups if desired)
      document.querySelectorAll('.device-frame').forEach(frame => {
        frame.style.borderColor = 'rgba(123, 79, 255, 0.4)';
      });
    } else {
      showToast("Dark Mood Restored");
      document.querySelectorAll('.device-frame').forEach(frame => {
        frame.style.borderColor = '';
      });
    }
  });

  // ── MENU LIST ITEM TOASTS ──
  document.querySelectorAll('.settings-item:not(.toggle-item)').forEach(item => {
    item.addEventListener('click', () => {
      const labelText = item.querySelector('span').textContent;
      showToast(`Opening: ${labelText}`);
    });
  });

  document.querySelector('.unlimited-card').addEventListener('click', () => {
    showToast("Checkout Unlimited Plan ($9.99/mo)");
  });

  // ── TOAST MESSAGES SYSTEM ──
  let toastTimeout;
  function showToast(message) {
    clearTimeout(toastTimeout);
    toastMessage.textContent = message;
    toast.classList.add('show');
    
    toastTimeout = setTimeout(() => {
      toast.classList.remove('show');
    }, 2000);
  }
});
