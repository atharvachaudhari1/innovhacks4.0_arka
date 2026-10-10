package com.google.mediapipe.examples.poselandmarker

import android.os.Bundle
import android.os.CountDownTimer
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import com.google.android.material.bottomsheet.BottomSheetDialogFragment
import com.google.mediapipe.examples.poselandmarker.databinding.BottomSheetSmartRestTimerBinding

class SmartRestTimerBottomSheet(
    private var initialSeconds: Int = 60,
    private val currentHeartRate: Int = 118,
    private val onTimerFinished: () -> Unit
) : BottomSheetDialogFragment() {

    private var _binding: BottomSheetSmartRestTimerBinding? = null
    private val binding get() = _binding!!

    private var countDownTimer: CountDownTimer? = null
    private var totalSeconds = initialSeconds
    private var remainingSeconds = initialSeconds

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = BottomSheetSmartRestTimerBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        binding.restHrBadge.text = if (currentHeartRate > 0) "❤️ $currentHeartRate BPM" else "❤️ 115 BPM"
        val isRecovered = currentHeartRate in 1..120
        if (isRecovered) {
            binding.recoveryStatusText.text = "Cardiovascular recovery optimal! Ready for next set."
            binding.recoveryIcon.text = "✅"
        } else {
            binding.recoveryStatusText.text = "Heart rate recovering. Deep breaths to lower cardiac strain."
            binding.recoveryIcon.text = "🫀"
        }

        binding.closeRestButton.setOnClickListener {
            dismiss()
        }

        binding.skipRestButton.setOnClickListener {
            stopTimer()
            dismiss()
            onTimerFinished()
        }

        binding.plus30Button.setOnClickListener {
            adjustTimer(30)
        }

        binding.minus15Button.setOnClickListener {
            adjustTimer(-15)
        }

        startTimer(remainingSeconds)
    }

    private fun startTimer(seconds: Int) {
        countDownTimer?.cancel()
        remainingSeconds = seconds
        totalSeconds = maxOf(totalSeconds, seconds)
        binding.restTimerProgress.max = totalSeconds

        countDownTimer = object : CountDownTimer((seconds * 1000).toLong(), 1000L) {
            override fun onTick(millisUntilFinished: Long) {
                remainingSeconds = (millisUntilFinished / 1000).toInt()
                binding.restTimerSecondsText.text = "$remainingSeconds"
                binding.restTimerProgress.progress = remainingSeconds
            }

            override fun onFinish() {
                binding.restTimerSecondsText.text = "0"
                binding.restTimerProgress.progress = 0
                activity?.let {
                    ElevenLabsService.getInstance(it).speak("Rest complete! Let's start the next set.")
                }
                dismiss()
                onTimerFinished()
            }
        }.start()
    }

    private fun adjustTimer(deltaSeconds: Int) {
        val newSeconds = (remainingSeconds + deltaSeconds).coerceAtLeast(5)
        startTimer(newSeconds)
    }

    private fun stopTimer() {
        countDownTimer?.cancel()
        countDownTimer = null
    }

    override fun onDestroyView() {
        stopTimer()
        _binding = null
        super.onDestroyView()
    }
}
