import SwiftUI

struct NotificationView: View {
    @EnvironmentObject private var vm: StudyViewModel
    private let allDays = ["월", "화", "수", "목", "금", "토", "일"]

    private let dayColors: [String: Color] = [
        "월": .cosmosOrange, "화": Color(hex: "F472B6"), "수": .cosmosTeal,
        "목": Color(hex: "A78BFA"), "금": Color(hex: "34D399"),
        "토": Color(hex: "FBBF24"), "일": Color(hex: "FC8181"),
    ]

    var body: some View {
        ZStack {
            Color.cosmosBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {

                    // Status banner
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(vm.notifEnabled ? Color.cosmosOrange.opacity(0.2) : Color.cosmosMuted.opacity(0.1))
                                .frame(width: 44, height: 44)
                            Image(systemName: vm.notifEnabled ? "bell.fill" : "bell.slash")
                                .foregroundColor(vm.notifEnabled ? .cosmosOrange : .cosmosMuted)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(vm.notifEnabled ? "알림 활성화됨" : "알림 꺼짐")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(vm.notifEnabled ? .cosmosOrange : .cosmosMuted)
                            Text(vm.notifEnabled ? "매일 설정한 시간에 알림을 보냅니다" : "아래에서 알림을 설정하세요")
                                .font(.caption)
                                .foregroundColor(.cosmosMuted)
                        }
                        Spacer()
                    }
                    .padding(18)
                    .background(Color.cosmosCard)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(vm.notifEnabled ? Color.cosmosOrange.opacity(0.4) : Color.cosmosBorder)
                    )

                    // Message
                    CosmosCardSection {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel("알림 메시지", icon: "text.bubble.fill", color: .cosmosTeal)
                            TextField("알림 내용 입력", text: $vm.notifMessage)
                                .foregroundColor(.cosmosText)
                                .padding(14)
                                .background(Color.cosmosBg)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cosmosBorder))
                        }
                    }

                    // Time
                    CosmosCardSection {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel("알림 시간", icon: "clock.fill", color: .cosmosOrange)
                            DatePicker("", selection: $vm.notifTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .colorScheme(.dark)
                                .tint(.cosmosOrange)
                        }
                    }

                    // Days
                    CosmosCardSection {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionLabel("알림 요일", icon: "calendar.badge.clock", color: Color(hex: "A78BFA"))
                            HStack(spacing: 8) {
                                ForEach(allDays, id: \.self) { day in
                                    let isOn = vm.notifDays.contains(day)
                                    let c = dayColors[day] ?? .cosmosOrange
                                    Button {
                                        if isOn { vm.notifDays.removeAll { $0 == day } }
                                        else { vm.notifDays.append(day) }
                                    } label: {
                                        VStack(spacing: 3) {
                                            Circle()
                                                .fill(isOn ? c : Color.cosmosBg)
                                                .frame(width: 36, height: 36)
                                                .overlay(
                                                    Text(day)
                                                        .font(.system(size: 12, weight: .bold))
                                                        .foregroundColor(isOn ? .white : .cosmosMuted)
                                                )
                                                .overlay(Circle().stroke(isOn ? c : Color.cosmosBorder, lineWidth: 1.5))
                                        }
                                    }
                                    .animation(.spring(response: 0.3), value: isOn)
                                }
                            }
                        }
                    }

                    // Action button
                    if vm.notifEnabled {
                        Button(role: .destructive) {
                            Task { await vm.disableNotifications() }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "bell.slash.fill")
                                Text("알림 끄기")
                            }
                            .font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(Color(hex: "FC8181").opacity(0.15))
                            .foregroundColor(Color(hex: "FC8181"))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "FC8181").opacity(0.4)))
                        }
                    } else {
                        CosmosButton(label: "알림 저장", icon: "bell.fill", isDisabled: !vm.notificationErrors.isEmpty) {
                            Task { await vm.enableNotifications() }
                        }
                    }

                    if let err = vm.error {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(Color(hex: "FC8181"))
                            .padding(12)
                            .background(Color(hex: "FC8181").opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    if !vm.notifEnabled && !vm.notificationErrors.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(vm.notificationErrors, id: \.self) { issue in
                                Text("• \(issue)")
                                    .font(.caption)
                                    .foregroundColor(.cosmosMuted)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Text("선택한 요일과 시간에 매일 알림이 울립니다.\niOS 설정에서 알림 권한을 허용해야 합니다.")
                        .font(.caption)
                        .foregroundColor(.cosmosMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 32)
                }
                .padding(20)
            }
        }
        .preferredColorScheme(.dark)
        .navigationTitle("학습 알림 🔔")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SectionLabel: View {
    let text: String
    let icon: String
    let color: Color

    init(_ text: String, icon: String, color: Color) {
        self.text = text; self.icon = icon; self.color = color
    }

    var body: some View {
        Label(text, systemImage: icon)
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(color)
    }
}
