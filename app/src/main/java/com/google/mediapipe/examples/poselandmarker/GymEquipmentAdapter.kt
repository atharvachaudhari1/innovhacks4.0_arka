package com.google.mediapipe.examples.poselandmarker

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView
import com.google.mediapipe.examples.poselandmarker.data.EquipmentWithExercise
import com.google.mediapipe.examples.poselandmarker.databinding.ItemGymEquipmentBinding

class GymEquipmentAdapter(
    private var items: List<EquipmentWithExercise>,
    private val onItemClick: (EquipmentWithExercise) -> Unit
) : RecyclerView.Adapter<GymEquipmentAdapter.ViewHolder>() {

    inner class ViewHolder(val binding: ItemGymEquipmentBinding) : RecyclerView.ViewHolder(binding.root)

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val binding = ItemGymEquipmentBinding.inflate(LayoutInflater.from(parent.context), parent, false)
        return ViewHolder(binding)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        val item = items[position]
        holder.binding.equipmentIcon.text = item.machine.icon
        holder.binding.equipmentName.text = item.machine.name
        
        val muscles = item.primaryExercise?.muscles?.joinToString(" • ") ?: item.machine.category
        holder.binding.equipmentMuscles.text = muscles
        
        val desc = if (item.machine.what.isNotEmpty()) item.machine.what else item.primaryExercise?.plan ?: "Gym equipment guide & workout setup"
        holder.binding.equipmentDesc.text = desc

        if (item.primaryExercise?.hasAiAnalysis == true) {
            holder.binding.equipmentBadge.text = "AI COACH"
            holder.binding.btnActionText.text = "Guide & Coach →"
        } else {
            holder.binding.equipmentBadge.text = "GUIDE"
            holder.binding.btnActionText.text = "View Setup →"
        }

        holder.itemView.setOnClickListener {
            onItemClick(item)
        }
    }

    override fun getItemCount(): Int = items.size

    fun updateList(newList: List<EquipmentWithExercise>) {
        items = newList
        notifyDataSetChanged()
    }
}
