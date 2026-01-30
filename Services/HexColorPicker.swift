import SwiftUI

/// Hex Color Picker - Converts between hex strings and RGB colors
struct HexColorPicker {

    /// Convert hex string to Color
    static func hexToColor(_ hex: String) -> Color? {
        let trimmed = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard trimmed.count == 6 else { return nil }

        let scanner = Scanner(string: trimmed)
        var hexNumber: UInt64 = 0

        guard scanner.scanHexInt64(&hexNumber) else { return nil }

        let red = Double((hexNumber >> 16) & 0xFF) / 255.0
        let green = Double((hexNumber >> 8) & 0xFF) / 255.0
        let blue = Double(hexNumber & 0xFF) / 255.0

        return Color(red: red, green: green, blue: blue)
    }

    /// Convert Color to hex string
    static func colorToHex(_ color: Color) -> String {
        let nsColor = NSColor(color)

        // Safely convert to RGB colorspace to avoid crash
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else {
            // Fallback: try to get components directly
            let components = nsColor.cgColor.components ?? [0, 0, 0, 1]
            let red = components.count > 0 ? components[0] : 0
            let green = components.count > 1 ? components[1] : 0
            let blue = components.count > 2 ? components[2] : 0
            return String(
                format: "#%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
        }

        let redInt = Int(rgbColor.redComponent * 255)
        let greenInt = Int(rgbColor.greenComponent * 255)
        let blueInt = Int(rgbColor.blueComponent * 255)

        return String(format: "#%02X%02X%02X", redInt, greenInt, blueInt)
    }

    /// Get RGB components as strings
    static func getRGBComponents(_ color: Color) -> (r: String, g: String, b: String) {
        let nsColor = NSColor(color)

        // Safely convert to RGB colorspace to avoid crash
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else {
            let components = nsColor.cgColor.components ?? [0, 0, 0, 1]
            let red = components.count > 0 ? Int(components[0] * 255) : 0
            let green = components.count > 1 ? Int(components[1] * 255) : 0
            let blue = components.count > 2 ? Int(components[2] * 255) : 0
            return (r: String(red), g: String(green), b: String(blue))
        }

        let redInt = Int(rgbColor.redComponent * 255)
        let greenInt = Int(rgbColor.greenComponent * 255)
        let blueInt = Int(rgbColor.blueComponent * 255)

        return (
            r: String(redInt),
            g: String(greenInt),
            b: String(blueInt)
        )
    }

    /// Get RGB components as doubles (0-1 range)
    static func getRGBDouble(_ color: Color) -> (r: Double, g: Double, b: Double) {
        let nsColor = NSColor(color)

        // Safely convert to RGB colorspace to avoid crash
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else {
            let components = nsColor.cgColor.components ?? [0, 0, 0, 1]
            let red = components.count > 0 ? Double(components[0]) : 0
            let green = components.count > 1 ? Double(components[1]) : 0
            let blue = components.count > 2 ? Double(components[2]) : 0
            return (r: red, g: green, b: blue)
        }

        return (
            r: Double(rgbColor.redComponent), g: Double(rgbColor.greenComponent),
            b: Double(rgbColor.blueComponent)
        )
    }

    /// Create color from RGB (0-255 range)
    static func rgbToColor(r: Int, g: Int, b: Int) -> Color {
        let red = Double(max(0, min(255, r))) / 255.0
        let green = Double(max(0, min(255, g))) / 255.0
        let blue = Double(max(0, min(255, b))) / 255.0
        return Color(red: red, green: green, blue: blue)
    }

    /// Validate hex string
    static func isValidHex(_ hex: String) -> Bool {
        let trimmed = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard trimmed.count == 6 else { return false }
        let scanner = Scanner(string: trimmed)
        var hexNumber: UInt64 = 0
        return scanner.scanHexInt64(&hexNumber)
    }
}

/// Hex Color Picker View Component
struct ColorPickerView: View {
    @Binding var selectedColor: Color
    @State private var hexInput: String = ""
    @State private var rInput: String = ""
    @State private var gInput: String = ""
    @State private var bInput: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Color preview
            VStack(spacing: 8) {
                Text("Color Preview")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedColor)
                        .frame(height: 60)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hex")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(HexColorPicker.colorToHex(selectedColor))
                            .font(.caption)
                            .monospaced()

                        Divider()

                        Text("RGB")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        let rgb = HexColorPicker.getRGBComponents(selectedColor)
                        Text("\(rgb.r), \(rgb.g), \(rgb.b)")
                            .font(.caption)
                            .monospaced()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)

            // Hex input
            VStack(alignment: .leading, spacing: 6) {
                Text("Hex Color Code")
                    .font(.caption)
                    .fontWeight(.semibold)

                HStack(spacing: 8) {
                    TextField("#RRGGBB", text: $hexInput)
                        .textFieldStyle(.roundedBorder)
                        .monospaced()
                        .font(.caption)
                        .onChange(of: hexInput) { _ in
                            if HexColorPicker.isValidHex(hexInput) {
                                if let color = HexColorPicker.hexToColor(hexInput) {
                                    selectedColor = color
                                    updateRGBInputs()
                                }
                            }
                        }

                    Button(action: {
                        hexInput = HexColorPicker.colorToHex(selectedColor)
                    }) {
                        Image(systemName: "arrowshape.turn.up.left")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }

            // RGB inputs
            VStack(alignment: .leading, spacing: 6) {
                Text("RGB Values (0-255)")
                    .font(.caption)
                    .fontWeight(.semibold)

                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("R")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        TextField("0", text: $rInput)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: rInput) { _ in updateColorFromRGB() }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("G")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        TextField("0", text: $gInput)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: gInput) { _ in updateColorFromRGB() }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("B")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        TextField("0", text: $bInput)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: bInput) { _ in updateColorFromRGB() }
                    }
                }
            }

            // Color sliders
            VStack(alignment: .leading, spacing: 12) {
                Text("Adjust Sliders")
                    .font(.caption)
                    .fontWeight(.semibold)

                let rgb = HexColorPicker.getRGBComponents(selectedColor)
                let rValue = Double(Int(rgb.r) ?? 0)
                let gValue = Double(Int(rgb.g) ?? 0)
                let bValue = Double(Int(rgb.b) ?? 0)

                VStack(spacing: 4) {
                    HStack {
                        Text("R")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(width: 16)
                        Slider(
                            value: Binding(
                                get: { rValue },
                                set: { newValue in
                                    rInput = String(Int(newValue))
                                    updateColorFromRGB()
                                }
                            ), in: 0...255)
                        Text(rgb.r)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(width: 30, alignment: .trailing)
                    }
                }

                VStack(spacing: 4) {
                    HStack {
                        Text("G")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .frame(width: 16)
                        Slider(
                            value: Binding(
                                get: { gValue },
                                set: { newValue in
                                    gInput = String(Int(newValue))
                                    updateColorFromRGB()
                                }
                            ), in: 0...255)
                        Text(rgb.g)
                            .font(.caption)
                            .foregroundStyle(.green)
                            .frame(width: 30, alignment: .trailing)
                    }
                }

                VStack(spacing: 4) {
                    HStack {
                        Text("B")
                            .font(.caption)
                            .foregroundStyle(.blue)
                            .frame(width: 16)
                        Slider(
                            value: Binding(
                                get: { bValue },
                                set: { newValue in
                                    bInput = String(Int(newValue))
                                    updateColorFromRGB()
                                }
                            ), in: 0...255)
                        Text(rgb.b)
                            .font(.caption)
                            .foregroundStyle(.blue)
                            .frame(width: 30, alignment: .trailing)
                    }
                }
            }
        }
        .onAppear {
            hexInput = HexColorPicker.colorToHex(selectedColor)
            updateRGBInputs()
        }
    }

    private func updateRGBInputs() {
        let rgb = HexColorPicker.getRGBComponents(selectedColor)
        rInput = rgb.r
        gInput = rgb.g
        bInput = rgb.b
    }

    private func updateColorFromRGB() {
        let r = Int(rInput) ?? 0
        let g = Int(gInput) ?? 0
        let b = Int(bInput) ?? 0
        selectedColor = HexColorPicker.rgbToColor(r: r, g: g, b: b)
        hexInput = HexColorPicker.colorToHex(selectedColor)
    }
}

#if canImport(PreviewsMacros)
    #Preview {
        ColorPickerView(selectedColor: .constant(Color.blue))
    }
#endif
