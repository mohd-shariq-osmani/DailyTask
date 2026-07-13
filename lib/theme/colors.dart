import 'package:flutter/material.dart';

// ── Background Surfaces (Cinema Dark + OLED Hybrid) ──────────────────
const Color darkBackground = Color(0xFF050507);      // Near-black, avoids OLED smear
const Color darkSurface = Color(0xFF0D0D11);         // Elevated card surface
const Color darkSurfaceVariant = Color(0xFF131318);  // Slightly lighter surface
const Color glassBackground = Color(0x0AFFFFFF);     // Glassmorphic overlay (4% white)
const Color glassBorder = Color(0x0FFFFFFF);         // Hairline border (6% white)

// ── Accent Palette ───────────────────────────────────────────────────
const Color accentViolet = Color(0xFF8B5CF6);        // Primary accent — refined violet
const Color accentVioletLight = Color(0xFFA78BFA);   // Lighter violet for highlights
const Color accentVioletGlow = Color(0x268B5CF6);    // Glow behind accent elements (15%)
const Color accentVioletMuted = Color(0xFF6D28D9);   // Deeper violet for gradients

// ── Semantic Colors ──────────────────────────────────────────────────
const Color greenAccent = Color(0xFF34D399);         // Emerald green — success/completed
const Color redAccent = Color(0xFFEF4444);           // Destructive/delete
const Color amberAccent = Color(0xFFFBBF24);         // Warning/attention

// ── Typography Colors ────────────────────────────────────────────────
const Color textPrimary = Color(0xFFF0F0F3);         // Warm white — primary text
const Color textSecondary = Color(0xFF6B7280);       // Muted gray — labels & captions
const Color textTertiary = Color(0xFF404040);        // Disabled/completed text
const Color textOnAccent = Color(0xFFFFFFFF);        // Text on accent backgrounds

// ── Preset Task Colors (harmonious premium neon palette) ─────────────
const List<String> presetTaskColors = [
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
];
