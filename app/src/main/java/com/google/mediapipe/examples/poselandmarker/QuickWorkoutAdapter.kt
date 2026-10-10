package com.google.mediapipe.examples.poselandmarker

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView
import com.google.mediapipe.examples.poselandmarker.databinding.ItemQuickWorkoutBinding

data class QuickWorkout(
    val id: String,
    val name: String,
    val icon: String,
    val muscles: String,
    val workoutType: String
)

class QuickWorkoutAdapter(
    private val items: List<QuickWorkout>,
    private val onItemClick: (QuickWorkout) -> Unit
) : RecyclerView.Adapter<QuickWorkoutAdapter.ViewHolder>() {

    inner class ViewHolder(val binding: ItemQuickWorkoutBinding) : RecyclerView.ViewHolder(binding.root)

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val binding = ItemQuickWorkoutBinding.inflate(LayoutInflater.from(parent.context), parent, false)
        return ViewHolder(binding)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        val item = items[position]
        holder.binding.quickIcon.text = item.icon
        holder.binding.quickName.text = item.name
        holder.binding.quickDesc.text = item.muscles

        holder.itemView.setOnClickListener {
            onItemClick(item)
        }
    }

    override fun getItemCount(): Int = items.size
}
