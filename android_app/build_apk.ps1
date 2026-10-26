# Builds PeekaPoo.apk without Gradle: aapt2 -> javac -> d8 -> zipalign -> apksigner.
# Needs the Android SDK in %USERPROFILE%\android-sdk and a JDK (DevEco Studio ships one).
#   -Hub  address the app connects to by default, e.g. https://yourname.pythonanywhere.com
param([string]$Hub = "")
$ErrorActionPreference = "Stop"
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Sdk  = "$env:USERPROFILE\android-sdk"
$Bt   = "$Sdk\build-tools\34.0.0"
$Jar  = "$Sdk\platforms\android-34\android.jar"
$Jdk  = "D:\DevEco Studio\jbr"
$env:JAVA_HOME = $Jdk

if (-not (Test-Path $Jar) -or -not (Test-Path "$Bt\aapt2.exe")) {
    Write-Host "Installing Android platform 34 + build-tools 34.0.0 (answer y to the licence)..."
    & "$Sdk\cmdline-tools\latest\bin\sdkmanager.bat" "--sdk_root=$Sdk" "platforms;android-34" "build-tools;34.0.0"
}

$Out = "$Here\build"
if (Test-Path $Out) { Remove-Item $Out -Recurse -Force }
New-Item -ItemType Directory -Force "$Out\assets\www", "$Out\classes" | Out-Null

# web app -> assets/www (same files the hub serves at /m/)
Copy-Item "$Here\..\mobile_app\*" "$Out\assets\www" -Recurse
if ($Hub) {
    $AppJs = "$Out\assets\www\app.js"
    $Js = [IO.File]::ReadAllText($AppJs) -replace 'const DEFAULT_HUB = "[^"]*";', "const DEFAULT_HUB = `"$($Hub.TrimEnd('/'))`";"
    [IO.File]::WriteAllText($AppJs, $Js)
    Write-Host "Default hub: $Hub"
}

& "$Bt\aapt2.exe" compile --dir "$Here\res" -o "$Out\res.zip"
& "$Bt\aapt2.exe" link -o "$Out\unsigned.apk" -I $Jar --manifest "$Here\AndroidManifest.xml" `
    -A "$Out\assets" "$Out\res.zip" --min-sdk-version 24 --target-sdk-version 34 `
    --version-code 1 --version-name 1.0.0
if ($LASTEXITCODE) { throw "aapt2 link failed" }

$Src = Get-ChildItem "$Here\src" -Recurse -Filter *.java | ForEach-Object FullName
& "$Jdk\bin\javac.exe" -source 8 -target 8 -classpath $Jar -d "$Out\classes" -nowarn $Src
if ($LASTEXITCODE) { throw "javac failed" }

$Classes = Get-ChildItem "$Out\classes" -Recurse -Filter *.class | ForEach-Object FullName
& "$Bt\d8.bat" --lib $Jar --min-api 24 --output $Out $Classes
if ($LASTEXITCODE) { throw "d8 failed" }

Push-Location $Out
& "$Bt\aapt.exe" add unsigned.apk classes.dex | Out-Null
Pop-Location
if ($LASTEXITCODE) { throw "adding classes.dex failed" }

& "$Bt\zipalign.exe" -f 4 "$Out\unsigned.apk" "$Out\aligned.apk"

$Ks = "$Here\debug.keystore"
if (-not (Test-Path $Ks)) {
    & "$Jdk\bin\keytool.exe" -genkeypair -keystore $Ks -storepass android -keypass android -alias peekapoo `
        -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=PeekaPoo, O=Team InsideOut, C=MY"
}
& "$Bt\apksigner.bat" sign --ks $Ks --ks-pass pass:android --key-pass pass:android --out "$Here\PeekaPoo.apk" "$Out\aligned.apk"
if ($LASTEXITCODE) { throw "apksigner failed" }

Write-Host "`nDone: $Here\PeekaPoo.apk"
