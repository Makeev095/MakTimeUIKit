import SwiftUI

struct RootSwiftUIView: View {
    @ObservedObject var authService: AuthService
    @ObservedObject var socketService: SocketService
    @ObservedObject var callCoordinator: CallCoordinator

    var body: some View {
        Group {
            if authService.isLoading && authService.token != nil {
                splash
            } else if authService.isAuthenticated {
                MainShellView(
                    authService: authService,
                    socketService: socketService,
                    callCoordinator: callCoordinator
                )
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
            ProgressView()
                .tint(MTColor.accent)
                .scaleEffect(1.2)
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
