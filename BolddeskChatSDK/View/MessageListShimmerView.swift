import SwiftUI

struct MessageListShimmerView: View {
    var body: some View {
        VStack(spacing: 16) {
            ForEach(0..<15) { index in
                if index % 2 == 0 { // Simulate agent message
                    ShimmerAgentMessageRow()
                } else { // Simulate customer message
                    ShimmerCustomerMessageRow()
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }
}

struct ShimmerAgentMessageRow: View {

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .frame(width: 32, height: 32)
                .foregroundColor(Color.gray.opacity(0.1))
                .shimmer()

            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 4) // Agent name placeholder
                    .frame(width: 80, height: 16)
                    .foregroundColor(Color.gray.opacity(0.1))
                    .shimmer()
                
                RoundedRectangle(cornerRadius: 12)
                    .frame(width: 223, height: 36)
                    .foregroundColor(Color.gray.opacity(0.1))
                    .background(Color.gray.opacity(0.1))
                    .clipShape(CustomCorners(topLeft: 2, topRight: 12, bottomLeft: 12, bottomRight: 12))
                    .shimmer()
            }
            Spacer()
        }
    }
}

struct ShimmerCustomerMessageRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                    RoundedRectangle(cornerRadius: 12)
                        .frame(width: 223, height: 36)
                        .foregroundColor(Color.gray.opacity(0.1))
                        .background(Color.gray.opacity(0.1))
                        .clipShape(CustomCorners(topLeft: 12, topRight: 2, bottomLeft: 12, bottomRight: 12))
                        .shimmer()
            }
        }
    }
}

struct CategoryShimmerRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 16)
                .shimmer()
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 120, height: 12)
                .shimmer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.bgPrimary)
        .cornerRadius(8) // ✅ your requirement
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.borderPrimary, lineWidth: 1)
        )
    }
}
