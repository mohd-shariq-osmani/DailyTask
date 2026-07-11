package com.dailytask.app.ui.theme

import androidx.compose.ui.graphics.Color

// ── Background Surfaces (Cinema Dark + OLED Hybrid) ──────────────────
val DarkBackground = Color(0xFF050507)      // Near-black, avoids OLED smear
val DarkSurface = Color(0xFF0D0D11)         // Elevated card surface
val DarkSurfaceVariant = Color(0xFF131318)  // Slightly lighter surface for nested elements
val GlassBackground = Color(0x0AFFFFFF)     // Glassmorphic overlay (4% white)
val GlassBorder = Color(0x0FFFFFFF)         // Hairline border (6% white)

// ── Accent Palette ───────────────────────────────────────────────────
val AccentViolet = Color(0xFF8B5CF6)        // Primary accent — refined violet
val AccentVioletLight = Color(0xFFA78BFA)   // Lighter violet for highlights
val AccentVioletGlow = Color(0x268B5CF6)    // Glow behind accent elements (15%)
val AccentVioletMuted = Color(0xFF6D28D9)   // Deeper violet for gradients

// ── Semantic Colors ──────────────────────────────────────────────────
val GreenAccent = Color(0xFF34D399)         // Emerald green — success/completed
val RedAccent = Color(0xFFEF4444)           // Destructive/delete
val AmberAccent = Color(0xFFFBBF24)         // Warning/attention

// ── Typography Colors ────────────────────────────────────────────────
val TextPrimary = Color(0xFFF0F0F3)         // Warm white — primary text
val TextSecondary = Color(0xFF6B7280)       // Muted gray — labels & captions
val TextTertiary = Color(0xFF404040)        // Disabled/completed text
val TextOnAccent = Color(0xFFFFFFFF)        // Text on accent backgrounds

// ── Legacy aliases (for backward compat with widget code) ────────────
val PurpleAccent = AccentViolet
val PurpleAccentSecondary = AccentVioletMuted
val StrikeColor = AccentViolet
val TaskCompleted = TextTertiary

// ── Preset Task Colors (harmonious premium neon palette) ─────────────
val PresetTaskColors = listOf(
    "#8B5CF6", // Violet
    "#34D399", // Emerald
    "#F472B6", // Pink
    "#38BDF8", // Sky Blue
    "#FBBF24", // Amber
    "#FB923C", // Orange
    "#A78BFA", // Lavender
    "#2DD4BF", // Teal
    "#F87171", // Coral Red
    "#818CF8"  // Indigo
)
