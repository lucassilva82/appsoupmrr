import UIKit
import Flutter
import Firebase
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate {

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        FirebaseApp.configure()
        GeneratedPluginRegistrant.register(with: self)
        
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        
        // Não pede permissão aqui: o sistema perguntava na abertura e, logo
        // depois, o app mostrava a janela dele (duas perguntas seguidas). Quem
        // pede é o Dart (_checkNotificationPermission): primeiro explica, e só
        // no "Ativar" chama o pedido do sistema. Registrar no APNs não depende
        // da permissão (o token serve também para push silencioso).
        application.registerForRemoteNotifications()

        NSLog("===== iOS AppDelegate configurado (swizzling ON) =====")
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // APNs registrou com sucesso → repassa o device token ao Firebase.
    override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenStr = deviceToken.map { String(format: "%02x", $0) }.joined()
        NSLog("===== iOS ✅ APNs DEVICE TOKEN registrado: \(tokenStr.prefix(20))... =====")
        Messaging.messaging().apnsToken = deviceToken
        super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }

    // APNs falhou ao registrar → mostra o motivo no console.
    override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NSLog("===== iOS ❌ APNs REGISTRO FALHOU: \(error.localizedDescription) =====")
        super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        NSLog("===== iOS: FCM Token recebido: \(String(describing: fcmToken)) =====")
        if let token = fcmToken {
            // Ponte para o Flutter: o plugin Dart getToken() falha no simulador
            // (apns-token-not-set), mas o token EXISTE aqui. Gravamos em
            // UserDefaults com prefixo "flutter." para o SharedPreferences ler.
            UserDefaults.standard.set(token, forKey: "flutter.native_fcm_token")
            NSLog("===== iOS: FCM Token salvo em UserDefaults (flutter.native_fcm_token) =====")
        }
    }
}
