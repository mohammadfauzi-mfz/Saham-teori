"""Patch proyek android hasil `flutter create` : signing release (keystore tetap),
desugaring (flutter_local_notifications) dan izin manifest. Gagal keras bila pola tidak ketemu."""
import re, sys, pathlib

root = pathlib.Path('android')
kts = root / 'app' / 'build.gradle.kts'
grv = root / 'app' / 'build.gradle'
manifest = root / 'app' / 'src' / 'main' / 'AndroidManifest.xml'

def die(m):
    print('PATCH GAGAL:', m); sys.exit(1)

if kts.exists():
    s = kts.read_text()
    s = re.sub(r'(compileOptions\s*\{)', r'\1\n        isCoreLibraryDesugaringEnabled = true', s, count=1)
    sign = '''    signingConfigs {
        create("release") {
            storeFile = file(System.getenv("KS_FILE"))
            storePassword = System.getenv("KS_PASS")
            keyAlias = System.getenv("KS_ALIAS")
            keyPassword = System.getenv("KS_KEYPASS")
        }
    }

'''
    if 'buildTypes {' not in s: die('buildTypes tidak ditemukan (kts)')
    s = s.replace('buildTypes {', sign + '    buildTypes {', 1)
    s, n = re.subn(r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)', 'signingConfig = signingConfigs.getByName("release")', s)
    if n != 1: die('signingConfig debug tidak ditemukan (kts)')
    s += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    if 'isCoreLibraryDesugaringEnabled' not in s: die('compileOptions tidak ditemukan (kts)')
    kts.write_text(s)
elif grv.exists():
    s = grv.read_text()
    s = re.sub(r'(compileOptions\s*\{)', r'\1\n        coreLibraryDesugaringEnabled true', s, count=1)
    sign = '''    signingConfigs {
        release {
            storeFile file(System.getenv("KS_FILE"))
            storePassword System.getenv("KS_PASS")
            keyAlias System.getenv("KS_ALIAS")
            keyPassword System.getenv("KS_KEYPASS")
        }
    }

'''
    if 'buildTypes {' not in s: die('buildTypes tidak ditemukan (groovy)')
    s = s.replace('buildTypes {', sign + '    buildTypes {', 1)
    s, n = re.subn(r'signingConfig\s+signingConfigs\.debug', 'signingConfig signingConfigs.release', s)
    if n != 1: die('signingConfig debug tidak ditemukan (groovy)')
    s += '\ndependencies {\n    coreLibraryDesugaring "com.android.tools:desugar_jdk_libs:2.1.4"\n}\n'
    if 'coreLibraryDesugaringEnabled' not in s: die('compileOptions tidak ditemukan (groovy)')
    grv.write_text(s)
else:
    die('build.gradle(.kts) tidak ada')

m = manifest.read_text()
perms = ''.join('    <uses-permission android:name="android.permission.%s"/>\n' % p for p in
                ['INTERNET', 'POST_NOTIFICATIONS', 'REQUEST_INSTALL_PACKAGES', 'RECEIVE_BOOT_COMPLETED', 'WAKE_LOCK'])
m = m.replace('<application', perms + '    <application', 1)
m = re.sub(r'android:label="[^"]*"', 'android:label="Saham Teori"', m, count=1)
manifest.write_text(m)
print('patch android OK')
