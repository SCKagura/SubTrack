import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:subtrack/src/features/authentication/data/user_profile_repository.dart';

part 'auth_repository.g.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  AuthRepository(this._auth, this._googleSignIn);

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  // ฟังก์ชันล็อกอินด้วย Google (หัวใจสำคัญของระบบ Auth)
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // 1. Trigger Google Sign In flow
      // เรียกหน้าต่างล็อกอินของ Google ขึ้นมาให้ผู้ใช้เลือกบัญชี
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // ถ้าผู้ใช้กดยกเลิก ก็จบการทำงาน

      // 2. Obtain the auth details from the request
      // ขอข้อมูล Authentication (Token) จาก Google
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // 3. Create a new credential
      // สร้าง "บัตรผ่าน" (Credential) โดยใช้ Access Token และ ID Token ที่ได้มา
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Sign in to Firebase with credential
      // เอาบัตรผ่านมาล็อกอินเข้าสู่ระบบ Firebase (Backend ของเรา)
      // เมื่อสำเร็จ Firebase จะสร้าง Session ให้ผู้ใช้ใช้งานแอปได้
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      // Handle error
      rethrow;
    }
  }

  Future<void> signInAnonymously() async {
    await _auth.signInAnonymously();
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(AuthRepositoryRef ref) {
  return AuthRepository(FirebaseAuth.instance, GoogleSignIn());
}

@riverpod
Stream<User?> authState(AuthStateRef ref) {
  return ref.watch(authRepositoryProvider).authStateChanges().asyncMap((
    user,
  ) async {
    if (user != null) {
      // Ensure profile exists when user logs in
      await ref.read(userProfileRepositoryProvider).ensureUserInitialized(user);
    }
    return user;
  });
}
