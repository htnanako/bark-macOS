import SwiftUI

struct StatusBadge: View {
    let title: String
    let value: String
    let detail: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(tint)
                    .frame(width: 8, height: 8)

                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(Color(red: 0.43, green: 0.51, blue: 0.58))
            }

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.15, green: 0.19, blue: 0.23))
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Text(detail)
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundStyle(Color(red: 0.35, green: 0.41, blue: 0.48))
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(minHeight: 122, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.70))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(tint.opacity(0.24), lineWidth: 1.2)
                )
                .shadow(color: tint.opacity(0.08), radius: 20, x: 0, y: 12)
        )
    }
}
