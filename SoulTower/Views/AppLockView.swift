import SwiftUI

struct AppLockView: View {
    @EnvironmentObject private var securityManager: AppSecurityManager
    @State private var password = ""
    @State private var unlocking = false
    @FocusState private var passwordFocused: Bool

    var body: some View {
        ZStack {
            BrandBackground()
            VStack(spacing: 22) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(BrandTheme.teal)
                VStack(spacing: 7) {
                    Text("心塔已锁定")
                        .font(.largeTitle.bold())
                    Text("客户资料只在验证身份后显示")
                        .foregroundStyle(.secondary)
                }
                SecureField("输入应用密码", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 340)
                    .focused($passwordFocused)
                    .onSubmit { unlockWithPassword() }
                Button(unlocking ? "正在验证…" : "解锁") {
                    unlockWithPassword()
                }
                .buttonStyle(.borderedProminent)
                .disabled(unlocking || password.isEmpty)

                if securityManager.biometricUnlockEnabled {
                    Button {
                        Task { await securityManager.unlockWithBiometrics() }
                    } label: {
                        Label("使用 \(securityManager.biometryLabel)", systemImage: "faceid")
                    }
                    .buttonStyle(.bordered)
                }

                if !securityManager.errorMessage.isEmpty {
                    Text(securityManager.errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(34)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26))
            .padding()
        }
        .onAppear { passwordFocused = true }
    }

    private func unlockWithPassword() {
        guard !password.isEmpty else { return }
        unlocking = true
        Task {
            await securityManager.unlock(password: password)
            password = ""
            unlocking = false
        }
    }
}
