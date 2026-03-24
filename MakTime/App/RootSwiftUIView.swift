import SwiftUI
import Lottie

// MARK: - UI / layout — корень SwiftUI после запуска
// Ветка: splash (Lottie) / MainShellView / Auth (UIKit в Representable). Фон корня — MTColor.bgPrimary.

struct RootSwiftUIView: View {
    @ObservedObject var authService: AuthService
    @ObservedObject var socketService: SocketService
    @ObservedObject var callCoordinator: CallCoordinator

    var body: some View {
        Group {
            if authService.isLoading && authService.token != nil {
                splash
            } else if authService.isAuthenticated {
                ZStack {
                    MTColor.bgPrimary.ignoresSafeArea()
                    MainShellView(
                        authService: authService,
                        socketService: socketService,
                        callCoordinator: callCoordinator
                    )
                }
            } else {
                AuthSwiftUIView(authService: authService)
                    .ignoresSafeArea()
            }
        }
        .preferredColorScheme(.dark)
    }

    private var splash: some View {
        ZStack {
            MTColor.bgPrimary.ignoresSafeArea()
            LottieView(animation: LottieAnimation.named("loading_dots", bundle: .main))
                .looping()
                .resizable()
                .frame(width: 120, height: 120)
        }
    }
}
