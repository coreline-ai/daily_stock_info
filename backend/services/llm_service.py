from __future__ import annotations

import json
import os
import hashlib
from datetime import datetime, timezone
from typing import Any
from pydantic import BaseModel, ValidationError

try:
    from openai import OpenAI
except Exception:  # pragma: no cover - optional dependency
    OpenAI = None

try:
    from zhipuai import ZhipuAI
except Exception:  # pragma: no cover - optional dependency
    ZhipuAI = None


DEFAULT_OPENAI_BASE_URL = "https://api.z.ai/api/coding/paas/v4"
PROMPT_VERSION = "v2-guardrail"
FORBIDDEN_CLAIMS = (
    "원금 보장",
    "확정 수익",
    "무조건 수익",
    "반드시 오릅니다",
    "투자 자문",
)
MODEL_ALIAS_MAP = {
    "GLM4.7": "GLM-4.7",
    "glm4.7": "glm-4.7",
}


def _normalize_model_id(model: str) -> str:
    value = (model or "").strip()
    if not value:
        return "GLM-4.7"
    return MODEL_ALIAS_MAP.get(value, value)


DEFAULT_MODEL = _normalize_model_id(os.getenv("ZHIPU_MODEL", "GLM4.7"))
DEFAULT_PROBE_TIMEOUT_SEC = 12.0
DEFAULT_CANDIDATE_MODELS = ["GLM-4.7", "glm-4.7", "GLM4.7", "glm4.7"]


class RiskFactorSchema(BaseModel):
    id: str
    description: str


class AiReportSchema(BaseModel):
    summary: str
    conclusion: str
    riskFactors: list[RiskFactorSchema]

_LLM_RUNTIME: dict[str, Any] = {
    "initialized": False,
    "checkedAt": None,
    "provider": "none",
    "baseUrl": DEFAULT_OPENAI_BASE_URL,
    "configuredModel": os.getenv("ZHIPU_MODEL", "GLM4.7"),
    "requestedModel": DEFAULT_MODEL,
    "effectiveModel": DEFAULT_MODEL,
    "candidateModels": [],
    "validated": False,
    "autoCorrected": False,
    "warnings": [],
    "probeResults": [],
}


def _utc_iso_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _dedupe_keep_order(values: list[str]) -> list[str]:
    out: list[str] = []
    seen: set[str] = set()
    for value in values:
        normalized = value.strip()
        if not normalized:
            continue
        key = normalized.lower()
        if key in seen:
            continue
        seen.add(key)
        out.append(normalized)
    return out


def _collect_model_candidates(requested_model: str) -> list[str]:
    env_candidates = [
        token.strip()
        for token in os.getenv("ZHIPU_MODEL_CANDIDATES", "").split(",")
        if token.strip()
    ]
    raw = [requested_model, *env_candidates, *DEFAULT_CANDIDATE_MODELS]
    expanded: list[str] = []
    for model in raw:
        expanded.append(model)
        alias = MODEL_ALIAS_MAP.get(model)
        if alias:
            expanded.append(alias)
    expanded.append(_normalize_model_id(requested_model))
    return _dedupe_keep_order(expanded)


def _is_probe_enabled() -> bool:
    probe_flag = os.getenv("LLM_PROBE_ON_STARTUP", "").strip().lower()
    if probe_flag in {"0", "false", "no", "off"}:
        return False
    if probe_flag in {"1", "true", "yes", "on"}:
        return True
    # pytest에서는 기본적으로 외부 네트워크 호출을 피한다.
    if os.getenv("PYTEST_CURRENT_TEST"):
        return False
    return True


def _probe_timeout_seconds() -> float:
    raw = os.getenv("LLM_PROBE_TIMEOUT_SEC", "").strip()
    if not raw:
        return DEFAULT_PROBE_TIMEOUT_SEC
    try:
        parsed = float(raw)
    except ValueError:
        return DEFAULT_PROBE_TIMEOUT_SEC
    return min(max(parsed, 1.0), 60.0)


def _probe_llm_model(
    *,
    api_key: str,
    model: str,
    base_url: str,
    timeout_sec: float,
) -> tuple[bool, str, str | None]:
    try:
        if OpenAI is not None:
            client = OpenAI(api_key=api_key, base_url=base_url, timeout=timeout_sec)
            client.chat.completions.create(
                model=model,
                messages=[
                    {"role": "system", "content": "You are a validator."},
                    {"role": "user", "content": "Reply with JSON only: {\"ok\":true}"},
                ],
                max_tokens=16,
                temperature=0.0,
            )
            return True, "zai-openai", None

        if ZhipuAI is not None:
            client = ZhipuAI(api_key=api_key)
            client.chat.completions.create(
                model=model,
                messages=[
                    {"role": "system", "content": "You are a validator."},
                    {"role": "user", "content": "Reply with JSON only: {\"ok\":true}"},
                ],
                temperature=0.0,
            )
            return True, "zhipu", None
        return False, "none", "No LLM SDK available"
    except Exception as exc:
        code = getattr(exc, "status_code", None)
        code_info = f"(status={code})" if code is not None else ""
        return False, "zai-openai" if OpenAI is not None else "zhipu", f"{exc.__class__.__name__}{code_info}"


def reset_llm_runtime_status() -> None:
    _LLM_RUNTIME.update(
        {
            "initialized": False,
            "checkedAt": None,
            "provider": "none",
            "baseUrl": DEFAULT_OPENAI_BASE_URL,
            "configuredModel": os.getenv("ZHIPU_MODEL", "GLM4.7"),
            "requestedModel": DEFAULT_MODEL,
            "effectiveModel": DEFAULT_MODEL,
            "candidateModels": [],
            "validated": False,
            "autoCorrected": False,
            "warnings": [],
            "probeResults": [],
        }
    )


def bootstrap_llm_runtime(*, probe: bool = True, force: bool = False) -> dict[str, Any]:
    if _LLM_RUNTIME["initialized"] and not force:
        return dict(_LLM_RUNTIME)

    configured_model = os.getenv("ZHIPU_MODEL", "GLM4.7").strip() or "GLM4.7"
    requested_model = _normalize_model_id(configured_model)
    base_url = (os.getenv("OPENAI_BASE_URL", DEFAULT_OPENAI_BASE_URL) or DEFAULT_OPENAI_BASE_URL).strip()
    api_key = os.getenv("ZHIPU_API_KEY", "").strip() or os.getenv("OPENAI_API_KEY", "").strip()
    timeout_sec = _probe_timeout_seconds()
    candidate_models = _collect_model_candidates(configured_model)

    warnings: list[str] = []
    probe_results: list[dict[str, Any]] = []
    validated = False
    provider = "none"
    effective_model = requested_model

    if not api_key:
        warnings.append("ZHIPU_API_KEY/OPENAI_API_KEY is missing.")
    elif probe and _is_probe_enabled():
        for model in candidate_models:
            ok, resolved_provider, error = _probe_llm_model(
                api_key=api_key,
                model=model,
                base_url=base_url,
                timeout_sec=timeout_sec,
            )
            probe_results.append({"model": model, "ok": ok, "error": error})
            if ok:
                validated = True
                provider = resolved_provider
                effective_model = model
                break
        if not validated:
            warnings.append("LLM startup probe failed for all model candidates.")
            if probe_results:
                last = probe_results[-1]
                warnings.append(f"Last probe error: {last.get('error', 'unknown')}")
    else:
        warnings.append("LLM startup probe skipped.")
        provider = "zai-openai" if OpenAI is not None else "zhipu" if ZhipuAI is not None else "none"

    auto_corrected = effective_model.lower() != configured_model.lower()
    if auto_corrected:
        warnings.append(f"Model auto-corrected: {configured_model} -> {effective_model}")

    _LLM_RUNTIME.update(
        {
            "initialized": True,
            "checkedAt": _utc_iso_now(),
            "provider": provider,
            "baseUrl": base_url,
            "configuredModel": configured_model,
            "requestedModel": requested_model,
            "effectiveModel": effective_model,
            "candidateModels": candidate_models,
            "validated": validated,
            "autoCorrected": auto_corrected,
            "warnings": warnings,
            "probeResults": probe_results[-5:],
        }
    )
    return dict(_LLM_RUNTIME)


def get_llm_runtime_status() -> dict[str, Any]:
    if not _LLM_RUNTIME["initialized"]:
        bootstrap_llm_runtime(probe=False)
    return dict(_LLM_RUNTIME)


def get_effective_model() -> str:
    status = get_llm_runtime_status()
    effective = str(status.get("effectiveModel", "")).strip()
    if effective:
        return effective
    requested = str(status.get("requestedModel", "")).strip()
    return requested if requested else DEFAULT_MODEL


def _confidence_payload(
    provider: str,
    news_summary: list[str],
    themes: list[str],
    risk_factors: list[dict[str, str]],
) -> dict[str, Any]:
    news_count = len([line for line in news_summary if line and "부족" not in line])
    theme_count = len(themes)
    risk_count = len(risk_factors)
    provider_ok = provider in {"zhipu", "zai-openai"}
    provider_bonus = 20 if provider_ok else 8
    raw_score = 35 + provider_bonus + (news_count * 8) + min(theme_count, 3) * 5 + min(risk_count, 3) * 4
    score = int(max(10, min(98, raw_score)))
    if score >= 75:
        level = "high"
    elif score >= 50:
        level = "medium"
    else:
        level = "low"

    warnings: list[str] = []
    if not provider_ok:
        warnings.append("LLM API 연결 실패로 폴백 리포트를 사용했습니다.")
    if news_count < 2:
        warnings.append("최신 뉴스 근거가 부족합니다.")
    if theme_count == 0:
        warnings.append("테마 매핑 근거가 약합니다.")

    return {"score": score, "level": level, "warnings": warnings}


def _fallback_report(stock: dict[str, Any], news_summary: list[str], themes: list[str]) -> dict[str, Any]:
    change_rate = float(stock.get("changeRate", 0.0))
    risk = "변동성 확대 가능성에 주의해야 합니다." if abs(change_rate) > 2 else "추세 유지 여부를 확인하며 진입하는 것이 유효합니다."
    risk_factors = [
        {"id": "R1", "description": risk},
        {
            "id": "R2",
            "description": news_summary[0] if news_summary else "핵심 뉴스 부재로 기술 지표 기반 판단 비중이 높습니다.",
        },
    ]
    confidence = _confidence_payload(
        provider="deterministic-fallback",
        news_summary=news_summary,
        themes=themes,
        risk_factors=risk_factors,
    )
    return {
        "provider": "deterministic-fallback",
        "model": DEFAULT_MODEL,
        "generatedAt": _utc_iso_now(),
        "summary": f"{stock.get('name', stock.get('code', '종목'))}은(는) 기술 지표 기준 {stock.get('summary', '')}",
        "conclusion": f"테마 {', '.join(themes[:2]) if themes else '일반'} 관점에서 {risk}",
        "riskFactors": risk_factors,
        "confidence": confidence,
    }


def _fallback_with_reason(
    stock: dict[str, Any],
    news_summary: list[str],
    themes: list[str],
    reason: str,
) -> dict[str, Any]:
    report = _fallback_report(stock, news_summary, themes)
    report["fallbackReason"] = reason
    confidence = report.get("confidence")
    if isinstance(confidence, dict):
        warnings = confidence.get("warnings")
        if not isinstance(warnings, list):
            warnings = []
        warnings = [*warnings, reason]
        confidence["warnings"] = warnings[:4]
    return report


def _build_prompt(stock: dict[str, Any], news_summary: list[str], themes: list[str], trade_date: str) -> str:
    payload = {
        "date": trade_date,
        "stock": {
            "code": stock.get("code"),
            "name": stock.get("name"),
            "price": stock.get("price"),
            "changeRate": stock.get("changeRate"),
            "summary": stock.get("summary"),
            "details": stock.get("details", {}),
            "targetPrice": stock.get("targetPrice"),
            "stopLoss": stock.get("stopLoss"),
        },
        "newsSummary3": news_summary,
        "themes": themes,
    }
    return (
        "너는 한국 주식 종가 전략 애널리스트다. 반드시 JSON만 반환하라. "
        "필수 필드: summary(string), conclusion(string), riskFactors(array<{id,description}>). "
        f"입력 데이터: {json.dumps(payload, ensure_ascii=False)}"
    )


def _extract_json(content: str) -> dict[str, Any]:
    content = content.strip()
    if content.startswith("```"):
        content = content.strip("`")
        lines = content.splitlines()
        if lines and lines[0].lower().startswith("json"):
            lines = lines[1:]
        content = "\n".join(lines)
    return json.loads(content)


def _contains_forbidden_claims(text: str) -> str | None:
    lowered = (text or "").strip().lower()
    if not lowered:
        return None
    for claim in FORBIDDEN_CLAIMS:
        if claim.lower() in lowered:
            return claim
    return None


def _validate_ai_report_schema(parsed: dict[str, Any]) -> tuple[bool, str | None]:
    try:
        AiReportSchema.model_validate(parsed)
        return True, None
    except ValidationError as exc:
        return False, f"schema-validation-failed:{exc.errors()[0].get('type', 'unknown')}"


def ensure_ai_report_shape(
    report: dict[str, Any] | None,
    *,
    stock: dict[str, Any],
    news_summary: list[str],
    themes: list[str],
) -> dict[str, Any]:
    if not report or not isinstance(report, dict):
        return _fallback_report(stock=stock, news_summary=news_summary, themes=themes)

    normalized: dict[str, Any] = dict(report)
    normalized.setdefault("provider", "deterministic-fallback")
    normalized.setdefault("model", DEFAULT_MODEL)
    normalized.setdefault("generatedAt", _utc_iso_now())
    normalized.setdefault("promptVersion", PROMPT_VERSION)
    normalized.setdefault("promptHash", "")
    normalized.setdefault("summary", "")
    normalized.setdefault("conclusion", "")
    if "fallbackReason" in normalized and not isinstance(normalized.get("fallbackReason"), str):
        normalized.pop("fallbackReason", None)
    if normalized.get("provider") == "deterministic-fallback" and "fallbackReason" not in normalized:
        normalized["fallbackReason"] = "Fallback report loaded from cache."

    risk_factors = normalized.get("riskFactors")
    if not isinstance(risk_factors, list):
        risk_factors = []
    normalized["riskFactors"] = risk_factors

    confidence = normalized.get("confidence")
    if not isinstance(confidence, dict):
        normalized["confidence"] = _confidence_payload(
            provider=str(normalized.get("provider", "deterministic-fallback")),
            news_summary=news_summary,
            themes=themes,
            risk_factors=risk_factors,
        )
    else:
        warnings = confidence.get("warnings")
        normalized["confidence"] = {
            "score": int(confidence.get("score", 50)),
            "level": confidence.get("level", "medium"),
            "warnings": warnings if isinstance(warnings, list) else [],
        }

    claim = _contains_forbidden_claims(str(normalized.get("summary", "")))
    claim = claim or _contains_forbidden_claims(str(normalized.get("conclusion", "")))
    if claim:
        fallback = _fallback_with_reason(stock, news_summary, themes, reason=f"guardrail-blocked-claim:{claim}")
        fallback["promptVersion"] = normalized.get("promptVersion", PROMPT_VERSION)
        fallback["promptHash"] = normalized.get("promptHash", "")
        return fallback

    return normalized


def generate_ai_report(
    stock: dict[str, Any],
    news_summary: list[str],
    themes: list[str],
    trade_date: str,
) -> dict[str, Any]:
    api_key = os.getenv("ZHIPU_API_KEY", "").strip() or os.getenv("OPENAI_API_KEY", "").strip()
    prompt = _build_prompt(stock, news_summary, themes, trade_date)
    prompt_hash = hashlib.sha256(prompt.encode("utf-8")).hexdigest()
    if not api_key:
        reason = "ZHIPU_API_KEY/OPENAI_API_KEY is missing."
        fallback = _fallback_with_reason(stock, news_summary, themes, reason=reason)
        fallback["promptVersion"] = PROMPT_VERSION
        fallback["promptHash"] = prompt_hash
        return fallback

    status = get_llm_runtime_status()
    model = get_effective_model()
    base_url = str(status.get("baseUrl") or DEFAULT_OPENAI_BASE_URL)

    try:
        provider = "deterministic-fallback"
        if OpenAI is not None:
            client = OpenAI(api_key=api_key, base_url=base_url)
            response = client.chat.completions.create(
                model=model,
                messages=[
                    {"role": "system", "content": "한국어로 투자 관점 분석을 제공하라."},
                    {"role": "user", "content": prompt},
                ],
                temperature=0.2,
            )
            provider = "zai-openai"
            content = response.choices[0].message.content if response and response.choices else ""
        elif ZhipuAI is not None:
            client = ZhipuAI(api_key=api_key)
            response = client.chat.completions.create(
                model=model,
                messages=[
                    {"role": "system", "content": "한국어로 투자 관점 분석을 제공하라."},
                    {"role": "user", "content": prompt},
                ],
                temperature=0.2,
            )
            provider = "zhipu"
            content = response.choices[0].message.content if response and response.choices else ""
        else:
            fallback = _fallback_with_reason(stock, news_summary, themes, reason="No LLM SDK available.")
            fallback["promptVersion"] = PROMPT_VERSION
            fallback["promptHash"] = prompt_hash
            return fallback

        parsed = _extract_json(content)
        is_valid, validation_error = _validate_ai_report_schema(parsed)
        if not is_valid:
            fallback = _fallback_with_reason(stock, news_summary, themes, reason=str(validation_error or "schema-validation-failed"))
            fallback["promptVersion"] = PROMPT_VERSION
            fallback["promptHash"] = prompt_hash
            return fallback

        risk_factors = parsed.get("riskFactors", [])
        guardrail_claim = _contains_forbidden_claims(str(parsed.get("summary", "")))
        guardrail_claim = guardrail_claim or _contains_forbidden_claims(str(parsed.get("conclusion", "")))
        if guardrail_claim:
            fallback = _fallback_with_reason(stock, news_summary, themes, reason=f"guardrail-blocked-claim:{guardrail_claim}")
            fallback["promptVersion"] = PROMPT_VERSION
            fallback["promptHash"] = prompt_hash
            return fallback
        confidence = _confidence_payload(
            provider=provider,
            news_summary=news_summary,
            themes=themes,
            risk_factors=risk_factors if isinstance(risk_factors, list) else [],
        )
        return {
            "provider": provider,
            "model": model,
            "generatedAt": _utc_iso_now(),
            "summary": str(parsed.get("summary", "")).strip(),
            "conclusion": str(parsed.get("conclusion", "")).strip(),
            "riskFactors": risk_factors if isinstance(risk_factors, list) else [],
            "confidence": confidence,
            "promptVersion": PROMPT_VERSION,
            "promptHash": prompt_hash,
        }
    except Exception as exc:
        fallback = _fallback_with_reason(stock, news_summary, themes, reason=f"LLM request failed: {exc.__class__.__name__}")
        fallback["promptVersion"] = PROMPT_VERSION
        fallback["promptHash"] = prompt_hash
        return fallback
