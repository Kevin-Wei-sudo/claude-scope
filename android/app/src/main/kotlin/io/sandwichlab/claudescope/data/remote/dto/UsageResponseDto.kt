package io.sandwichlab.claudescope.data.remote.dto

import io.sandwichlab.claudescope.data.model.ExtraUsage
import io.sandwichlab.claudescope.data.model.UsageBucket
import io.sandwichlab.claudescope.data.model.UsageResponse
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class UsageResponseDto(
    @SerialName("five_hour") val fiveHour: UsageBucketDto? = null,
    @SerialName("seven_day") val sevenDay: UsageBucketDto? = null,
    @SerialName("seven_day_opus") val sevenDayOpus: UsageBucketDto? = null,
    @SerialName("seven_day_sonnet") val sevenDaySonnet: UsageBucketDto? = null,
    @SerialName("extra_usage") val extraUsage: ExtraUsageDto? = null,
) {
    fun toModel(): UsageResponse = UsageResponse(
        fiveHour = fiveHour?.toModel(),
        sevenDay = sevenDay?.toModel(),
        sevenDayOpus = sevenDayOpus?.toModel(),
        sevenDaySonnet = sevenDaySonnet?.toModel(),
        extraUsage = extraUsage?.toModel(),
    )
}

@Serializable
data class UsageBucketDto(
    @SerialName("utilization") val utilization: Double? = null,
    @SerialName("resets_at") val resetsAt: String? = null,
) {
    fun toModel() = UsageBucket(utilization = utilization, resetsAt = resetsAt)
}

@Serializable
data class ExtraUsageDto(
    @SerialName("is_enabled") val isEnabled: Boolean = false,
    @SerialName("utilization") val utilization: Double? = null,
    @SerialName("used_credits") val usedCredits: Double? = null,
    @SerialName("monthly_limit") val monthlyLimit: Double? = null,
) {
    fun toModel() = ExtraUsage(
        isEnabled = isEnabled,
        utilization = utilization,
        usedCredits = usedCredits,
        monthlyLimit = monthlyLimit,
    )
}
