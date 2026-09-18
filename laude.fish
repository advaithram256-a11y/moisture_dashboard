#!/usr/bin/env fish

set WIN_BASE /run/media/thesupreme/Windows/Users/nsvhs/Downloads
set GRADLE_HOME_DIR $WIN_BASE/gradle-home
set PROJECT_DIR ~/development/moisture_dashboard

echo "== Step 1: Verify Windows partition is mounted and writable =="
if not test -d $WIN_BASE
    echo "ERROR: $WIN_BASE does not exist. Is the Windows drive mounted?"
    exit 1
end

touch $WIN_BASE/write_test.tmp
if test $status -ne 0
    echo "ERROR: Cannot write to $WIN_BASE. Partition may still be read-only."
    exit 1
end
rm $WIN_BASE/write_test.tmp
echo "OK: Windows partition is writable."

echo ""
echo "== Step 2: Create Gradle home directory on Windows drive =="
mkdir -p $GRADLE_HOME_DIR
echo "Created: $GRADLE_HOME_DIR"

echo ""
echo "== Step 3: Set GRADLE_USER_HOME persistently (fish universal var) =="
set -Ux GRADLE_USER_HOME $GRADLE_HOME_DIR
echo "GRADLE_USER_HOME set to: $GRADLE_USER_HOME"

echo ""
echo "== Step 4: Also set it in gradle.properties as a backup, in case env var isn't picked up by the wrapper =="
mkdir -p ~/.gradle
if not grep -q "org.gradle.user.home" ~/.gradle/gradle.properties 2>/dev/null
    echo "org.gradle.user.home=$GRADLE_HOME_DIR" >> ~/.gradle/gradle.properties
    echo "Added org.gradle.user.home to ~/.gradle/gradle.properties"
else
    echo "org.gradle.user.home already set in gradle.properties, skipping."
end

echo ""
echo "== Step 5: Clear old Gradle cache remnants left on root from failed attempts =="
rm -rf ~/.gradle/caches
rm -rf $PROJECT_DIR/android/.gradle
rm -rf $PROJECT_DIR/build
echo "Cleared stale caches on root."

echo ""
echo "== Step 6: Check for a stale/partial NDK download on the SDK drive =="
set SDK_NDK_DIR $WIN_BASE/sdkdontdeletethis/ndk
if test -d $SDK_NDK_DIR
    du -sh $SDK_NDK_DIR/* 2>/dev/null
    echo "If any folder above looks incomplete/tiny, delete it manually with: rm -rf '$SDK_NDK_DIR/<folder>'"
else
    echo "No ndk folder found yet at $SDK_NDK_DIR (expected on first successful download)."
end

echo ""
echo "== Step 7: Confirm root has enough free space for anything still cached there =="
df -h /

echo ""
echo "== Done =="
echo "GRADLE_USER_HOME is now: $GRADLE_HOME_DIR"
echo "IMPORTANT: close this terminal and open a NEW one so the env var takes effect,"
echo "then run:"
echo "  cd $PROJECT_DIR && flutter run"
