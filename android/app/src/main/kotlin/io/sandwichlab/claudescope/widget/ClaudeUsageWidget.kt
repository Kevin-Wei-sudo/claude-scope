package io.sandwichlab.claudescope.widget

import android.content.Context
import android.content.Intent
import android.text.format.DateUtils
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.LocalContext
import androidx.glance.LocalSize
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.color.ColorProvider
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import androidx.compose.ui.graphics.Color as ComposeColor
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.TextUnitType
import io.sandwichlab.claudescope.ClaudeScopeApp
import io.sandwichlab.claudescope.MainActivity
import kotlinx.coroutines.flow.first
import kotlin.math.roundToInt

/**
 * Home-screen widget matching iOS WidgetViews.swift (text-only variant).
 *
 * Data comes from [WidgetDataStore], which UsageService writes to after every
 * successful fetch. Visibility toggles come from [AppSettingsService] so the
 * user can hide 5h / 7d / reset from WidgetSettingsScreen.
 */
class ClaudeUsageWidget : GlanceAppWidget() {

    override val sizeMode = SizeMode.Responsive(
        setOf(SMALL_SIZE, MEDIUM_SIZE, LARGE_SIZE),
    )

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val snapshot = WidgetDataStore(context).read()
        val app = context.applicationContext as ClaudeScopeApp
        val settings = app.settingsService.settings.first()
        val options = WidgetVisibility(
            show5h = settings.widgetShow5h,
            show7d = settings.widgetShow7d,
            showReset = settings.widgetShowReset,
        )
        provideContent { WidgetContent(snapshot, options) }
    }

    @Composable
    private fun WidgetContent(snapshot: WidgetSnapshot, opts: WidgetVisibility) {
        val size = LocalSize.current
        when {
            size.width < MEDIUM_SIZE.width -> SmallLayout(snapshot)
            size.height < LARGE_SIZE.height -> MediumLayout(snapshot, opts)
            else -> LargeLayout(snapshot, opts)
        }
    }

    @Composable
    private fun SmallLayout(s: WidgetSnapshot) {
        Column(
            modifier = GlanceModifier.fillMaxSize().cardBg().padding(12.dp).openApp(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalAlignment = Alignment.Start,
        ) {
            Text("ClaudeScope", style = captionStyle())
            Spacer(GlanceModifier.height(4.dp))
            Text(
                text = "${(s.pct7d * 100).roundToInt()}%",
                style = TextStyle(
                    color = ColorProvider(TealGlance),
                    fontSize = TextUnit(32f, TextUnitType.Sp),
                    fontWeight = FontWeight.Bold,
                ),
            )
            Text("7-day", style = captionStyle())
        }
    }

    @Composable
    private fun MediumLayout(s: WidgetSnapshot, opts: WidgetVisibility) {
        Column(modifier = GlanceModifier.fillMaxSize().cardBg().padding(12.dp).openApp()) {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = GlanceModifier.fillMaxWidth()) {
                Text("ClaudeScope", style = captionStyle())
                Spacer(GlanceModifier.defaultWeight())
                Text(
                    text = "${(s.pct7d * 100).roundToInt()}%",
                    style = TextStyle(
                        color = ColorProvider(TealGlance),
                        fontSize = TextUnit(22f, TextUnitType.Sp),
                        fontWeight = FontWeight.Bold,
                    ),
                )
            }
            if (opts.show5h) {
                Spacer(GlanceModifier.height(10.dp))
                UsageRow(label = "5h", pct = s.pct5h, tint = TerracottaGlance)
            }
            if (opts.show7d) {
                Spacer(GlanceModifier.height(6.dp))
                UsageRow(label = "7d", pct = s.pct7d, tint = TealGlance)
            }
            if (opts.showReset && s.resetEpochMs != null) {
                Spacer(GlanceModifier.height(8.dp))
                Text("Resets ${relativeLabel(s.resetEpochMs)}", style = captionStyle())
            }
        }
    }

    @Composable
    private fun LargeLayout(s: WidgetSnapshot, opts: WidgetVisibility) {
        Column(modifier = GlanceModifier.fillMaxSize().cardBg().padding(14.dp).openApp()) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("ClaudeScope", style = captionStyle())
                Spacer(GlanceModifier.defaultWeight())
                Text(
                    text = "${(s.pct7d * 100).roundToInt()}%",
                    style = TextStyle(
                        color = ColorProvider(TealGlance),
                        fontSize = TextUnit(26f, TextUnitType.Sp),
                        fontWeight = FontWeight.Bold,
                    ),
                )
            }
            Spacer(GlanceModifier.height(12.dp))
            Row(modifier = GlanceModifier.fillMaxWidth()) {
                if (opts.show5h) {
                    WindowColumn(
                        label = "5-Hour",
                        pct = s.pct5h,
                        tint = TerracottaGlance,
                        modifier = GlanceModifier.defaultWeight(),
                    )
                    if (opts.show7d) Spacer(GlanceModifier.width(12.dp))
                }
                if (opts.show7d) {
                    WindowColumn(
                        label = "7-Day",
                        pct = s.pct7d,
                        tint = TealGlance,
                        modifier = GlanceModifier.defaultWeight(),
                    )
                }
            }
            Spacer(GlanceModifier.defaultWeight())
            if (opts.showReset && s.resetEpochMs != null) {
                Text("Resets ${relativeLabel(s.resetEpochMs)}", style = captionStyle())
            }
            if (s.lastUpdatedEpochMs > 0) {
                Text("Updated ${relativeLabel(s.lastUpdatedEpochMs)}", style = captionStyle())
            }
        }
    }

    @Composable
    private fun UsageRow(label: String, pct: Double, tint: ComposeColor) {
        Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = label,
                style = TextStyle(color = ColorProvider(SubtitleGlance), fontWeight = FontWeight.Medium),
            )
            Spacer(GlanceModifier.defaultWeight())
            Text(
                text = "${(pct * 100).roundToInt()}%",
                style = TextStyle(
                    color = ColorProvider(tint),
                    fontSize = TextUnit(18f, TextUnitType.Sp),
                    fontWeight = FontWeight.Bold,
                ),
            )
        }
    }

    @Composable
    private fun WindowColumn(label: String, pct: Double, tint: ComposeColor, modifier: GlanceModifier) {
        Column(modifier = modifier) {
            Text(
                text = label,
                style = TextStyle(color = ColorProvider(SubtitleGlance), fontWeight = FontWeight.Bold),
            )
            Spacer(GlanceModifier.height(4.dp))
            Text(
                text = "${(pct * 100).roundToInt()}%",
                style = TextStyle(
                    color = ColorProvider(tint),
                    fontSize = TextUnit(22f, TextUnitType.Sp),
                    fontWeight = FontWeight.Bold,
                ),
            )
        }
    }

    private fun captionStyle() = TextStyle(color = ColorProvider(SubtitleGlance))

    private fun GlanceModifier.cardBg(): GlanceModifier =
        background(ColorProvider(CardGlance)).cornerRadius(16.dp)

    @Composable
    private fun GlanceModifier.openApp(): GlanceModifier {
        val ctx = LocalContext.current
        return clickable(actionStartActivity(Intent(ctx, MainActivity::class.java)))
    }

    private data class WidgetVisibility(
        val show5h: Boolean,
        val show7d: Boolean,
        val showReset: Boolean,
    )

    companion object {
        val SMALL_SIZE = DpSize(110.dp, 110.dp)
        val MEDIUM_SIZE = DpSize(250.dp, 110.dp)
        val LARGE_SIZE = DpSize(250.dp, 250.dp)

        private val TealGlance = ComposeColor(0xFF2E8C80)
        private val TerracottaGlance = ComposeColor(0xFFCC6B4A)
        private val SubtitleGlance = ComposeColor(0xFF8C857F)
        private val CardGlance = ComposeColor(0xFFFFFFFF)
    }
}

private fun relativeLabel(epochMs: Long): String = DateUtils.getRelativeTimeSpanString(
    epochMs,
    System.currentTimeMillis(),
    DateUtils.MINUTE_IN_MILLIS,
    DateUtils.FORMAT_ABBREV_RELATIVE,
).toString()
