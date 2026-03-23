import SwiftUI
import Lottie

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
                AuthViewControllerRepresentable(authService: authService)
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

struct AuthViewControllerRepresentable: UIViewControllerRepresentable {
    let authService: AuthService

    func makeUIViewController(context: Context) -> AuthViewController {
        AuthViewController(authService: authService)
    }

    func updateUIViewController(_ uiViewController: AuthViewController, context: Context) {}
}
