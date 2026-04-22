package io.sandwichlab.claudescope.service.settings

import java.util.Locale

enum class AppLanguage(val tag: String) {
    System(""),
    English("en"),
    SimplifiedChinese("zh-Hans");

    fun toLocale(): Locale = when (this) {
        System -> Locale.getDefault()
        English -> Locale.ENGLISH
        SimplifiedChinese -> Locale.forLanguageTag("zh-Hans")
    }

    companion object {
        fun fromTag(tag: String?): AppLanguage = when (tag) {
            English.tag -> English
            SimplifiedChinese.tag -> SimplifiedChinese
            else -> System
        }
    }
}
