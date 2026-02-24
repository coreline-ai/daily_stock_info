# SameSite 쿠키 운영 가이드

이 프로젝트는 세션 쿠키를 사용하지 않지만, 추후 인증 도입 시 아래 기본값을 권장합니다.

- 기본: `SameSite=Lax`
- 외부 도메인 연동(OAuth callback 등) 필요 시: `SameSite=None; Secure`
- 민감 세션 쿠키는 항상 `HttpOnly; Secure` 적용

주의:
- `SameSite=None` 사용 시 HTTPS가 필수입니다.
- CSRF 토큰 정책은 인증/인가 도입 시 함께 적용합니다.
