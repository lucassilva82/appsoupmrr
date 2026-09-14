# Setup de Infraestrutura — SouPMRR

Documento de referência para configurar o projeto em uma máquina nova (iMac/Mac)
e conseguir buildar Android e iOS sem surpresas.

---

## 1. Identificadores do projeto

| Item | Valor |
|---|---|
| Nome do app | SouPMRR |
| `applicationId` (Android) | `pm.rr.soupmrr` |
| `PRODUCT_BUNDLE_IDENTIFIER` (iOS) | `com.pm.rr.soupmrr` |
| `DEVELOPMENT_TEAM` (Apple) | `2364NP776X` |
| Projeto Firebase | `minhapm-5ff71` |
| Repositório | `git@github.com:lucassilva82/appsoupmrr.git` (branch `main`) |

---

## 2. Versões das ferramentas (ambiente validado)

Estas são as versões exatas em que o projeto builda hoje. Divergir delas é a
causa mais comum de erro de build.

| Ferramenta | Versão |
|---|---|
| Flutter | **3.29.1** (channel `stable`) |
| Dart | **3.7.0** (vem junto com o Flutter) |
| Xcode | **26.5** (build 17F42) |
| CocoaPods | **1.16.2** |
| Ruby | **3.3.5** (arm64, via Homebrew) |
| Java / JDK | **OpenJDK 17.0.13** (Homebrew) |
| Gradle (wrapper) | **8.10.2** |
| Android Gradle Plugin | **8.7.0** |
| Node.js | **20.x** para as Cloud Functions (ver ressalva na seção 7) |
| Android NDK | **27.0.12077973** |

### Configuração Android (`android/app/build.gradle.kts`)

- `compileSdk = 36`
- `targetSdk = 36`
- `minSdk = 21`
- `sourceCompatibility` / `targetCompatibility` = Java 17
- `jvmTarget = "17"`
- Core library desugaring habilitado (`desugar_jdk_libs:1.2.2`)

> **Por que API 36:** o Google Play exige, a partir de **31/08/2026**, que o app
> tenha nível de API alvo no máximo 1 ano atrás da versão mais recente do Android.
> Não reduza o `targetSdk` abaixo de 36 ou o envio de atualizações será bloqueado.

### Configuração iOS

- Plataforma mínima do Podfile: **iOS 15.0**
- Workspace: `ios/Runner.xcworkspace` (**nunca** abrir o `.xcodeproj` direto)

---

## 3. Arquivos que NÃO estão no Git (transferir manualmente)

Estes arquivos estão no `.gitignore` por conterem segredos. **Eles não vêm no
`git clone`** e precisam ser copiados da máquina antiga por um meio seguro
(AirDrop, pendrive, 1Password, iCloud privado) — **nunca** commitar no repositório,
que é público.

| Arquivo | Para que serve | Consequência se faltar |
|---|---|---|
| `android/app/upload-keystore.jks` | Keystore de assinatura do release Android | **Sem ele é impossível publicar atualizações na Play Store.** Não existe como recuperar — faça backup em local seguro. |
| `android/key.properties` | Senhas/alias do keystore acima | Build de release Android falha na assinatura |

Formato esperado de `android/key.properties` (valores reais vêm da máquina antiga):

```properties
storePassword=<senha>
keyPassword=<senha>
keyAlias=<alias>
storeFile=../app/upload-keystore.jks
```

### Já versionados (vêm no clone, não precisa copiar)

- `ios/Runner/GoogleService-Info.plist`
- `android/app/google-services.json`
- `lib/firebase_options.dart`
- `ios/Podfile` e `ios/Podfile.lock`
- `firebase.json`, `functions/package.json`, `functions/matriculas_autorizadas.js`

---

## 4. Passo a passo na máquina nova

### 4.1 Pré-requisitos

```bash
# Homebrew (se ainda não tiver)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Java 17, Ruby, CocoaPods
brew install openjdk@17 ruby cocoapods

# Xcode 26.5+ pela App Store, e depois:
sudo xcodebuild -license accept
xcode-select --install
```

### 4.2 Flutter 3.29.1

```bash
mkdir -p ~/Development && cd ~/Development
git clone https://github.com/flutter/flutter.git -b stable
cd flutter && git checkout 3.29.1

# adicionar ao ~/.zshrc:
export PATH="$PATH:$HOME/Development/flutter/bin"

flutter doctor -v    # resolver o que aparecer em vermelho
```

### 4.3 Clonar e rodar

```bash
git clone git@github.com:lucassilva82/appsoupmrr.git
cd appsoupmrr

# copiar os 2 arquivos da seção 3 para os caminhos corretos AQUI

flutter pub get
cd ios && pod install && cd ..
flutter run
```

---

## 5. Builds

### Android (Play Store)

```bash
flutter build appbundle --release   # gera build/app/outputs/bundle/release/app-release.aab
```

Antes de cada envio, incrementar em `android/app/build.gradle.kts`:
`versionCode` (número inteiro sempre crescente) e `versionName`.

### iOS (App Store)

1. `cd ios && pod install`
2. Abrir **`ios/Runner.xcworkspace`** no Xcode
3. Selecionar **"Any iOS Device (arm64)"** (o Archive fica desabilitado em simulador)
4. **Product → Archive**
5. **Window → Organizer** → aba **Archives** → **Distribute App** → **App Store Connect** → **Upload**

---

## 6. Cloud Functions (Firebase)

```bash
npm install -g firebase-tools
firebase login
cd functions && npm install
firebase deploy --only functions
```

A lista de matrículas autorizadas a receber notificações individuais fica em
`functions/matriculas_autorizadas.js`. Após editar:

```bash
firebase deploy --only functions:notificarEscala
```

---

## 7. Armadilhas conhecidas

**`pod install` travado em "Installing BoringSSL-GRPC"**
Não está travado, está baixando. Esse pod faz um `git clone` do histórico
completo do repositório `google/boringssl` (centenas de MB). Em conexão lenta
leva **20–30 minutos na primeira vez**. Depois fica em cache e é instantâneo.
Não interrompa; se limpar o cache do CocoaPods, o download acontece de novo.

**Aviso do CocoaPods sobre "base configuration"**
Ao final do `pod install` aparece:
> CocoaPods did not set the base configuration of your project because your
> project already has a custom config set.

É **normal em projetos Flutter** (o Flutter gerencia os `.xcconfig` por conta
própria) e não impede o build.

**Node 20 vs Node mais novo**
`functions/package.json` declara `"engines": { "node": "20" }`. Se o Node local
for muito mais novo (23+), o deploy pode reclamar. Use `nvm use 20` dentro de
`functions/` se der problema.

**Deployment target iOS inconsistente**
O `Podfile` define `platform :ios, '15.0'`, mas o `post_install` força
`IPHONEOS_DEPLOYMENT_TARGET = '13.0'` nos pods. Está funcionando assim hoje;
se algum pod novo exigir 15.0+, alinhe os dois valores.

**Espaço em disco**
Build de iOS + caches do CocoaPods/Xcode consomem muitos GB. Mantenha pelo
menos ~20 GB livres antes de um Archive.

---

## 8. Checklist de migração de máquina

- [ ] Repositório clonado
- [ ] `android/app/upload-keystore.jks` copiado (**backup em local seguro!**)
- [ ] `android/key.properties` copiado
- [ ] Flutter 3.29.1 instalado e no PATH
- [ ] `flutter doctor` sem erros bloqueantes
- [ ] Xcode instalado + licença aceita + conta Apple (Team `2364NP776X`) logada
- [ ] `flutter pub get` OK
- [ ] `pod install` OK (paciência com o BoringSSL)
- [ ] `flutter run` rodando em dispositivo/simulador
- [ ] `flutter build appbundle --release` assinando corretamente
- [ ] Archive no Xcode concluindo
