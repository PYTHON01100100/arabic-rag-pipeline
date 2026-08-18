"""LLM Provider abstraction layer supporting Gemini, vLLM, and Ollama."""

import os
import json
import requests
from typing import Optional, Protocol
from abc import ABC, abstractmethod


class LLMProvider(ABC):
    """Abstract base class for LLM providers."""

    @abstractmethod
    def generate(self, system_prompt: str, context: str, user_message: str) -> str:
        """Generate response from the LLM."""
        pass

    @abstractmethod
    def is_available(self) -> bool:
        """Check if provider is properly configured and available."""
        pass


class GeminiProvider(LLMProvider):
    """Google Gemini API provider."""

    def __init__(self):
        from google import genai
        from google.genai import types

        self.genai = genai
        self.types = types
        self.model = os.getenv("GEMINI_MODEL", "gemini-2.0-flash")
        self.api_key = os.getenv("GEMINI_API_KEY")

        if self.api_key:
            self.client = genai.Client(api_key=self.api_key)
        else:
            self.client = None

    def is_available(self) -> bool:
        """Check if Gemini API key is configured."""
        return self.api_key is not None

    def generate(self, system_prompt: str, context: str, user_message: str) -> str:
        """Generate response using Gemini API."""
        if not self.is_available():
            return "خطأ: مفتاح Gemini API غير موجود"

        try:
            augmented_message = f"السياق المسترجع من المحاضرات:\n{context}\n\nسؤال الطالب: {user_message}"

            response = self.client.models.generate_content(
                model=self.model,
                contents=[self.types.Content(
                    role="user",
                    parts=[self.types.Part.from_text(text=augmented_message)]
                )],
                config=self.types.GenerateContentConfig(
                    system_instruction=system_prompt,
                ),
            )
            return response.text.strip()
        except Exception as e:
            return f"خطأ في Gemini: {str(e)}"


class VLLMProvider(LLMProvider):
    """vLLM OpenAI-compatible provider."""

    def __init__(self):
        self.base_url = os.getenv("VLLM_BASE_URL", "http://localhost:8000/v1")
        self.api_key = os.getenv("VLLM_API_KEY", "not-needed")
        self.model = os.getenv("VLLM_MODEL", "meta-llama/Llama-2-7b-chat-hf")
        self.max_tokens = int(os.getenv("VLLM_MAX_TOKENS", "2048"))
        self.temperature = float(os.getenv("VLLM_TEMPERATURE", "0.7"))

    def is_available(self) -> bool:
        """Check if vLLM server is running."""
        try:
            response = requests.get(
                f"{self.base_url}/models",
                headers={"Authorization": f"Bearer {self.api_key}"},
                timeout=2,
            )
            return response.status_code == 200
        except:
            return False

    def generate(self, system_prompt: str, context: str, user_message: str) -> str:
        """Generate response using vLLM."""
        if not self.is_available():
            return "خطأ: خادم vLLM غير متاح على " + self.base_url

        try:
            messages = [
                {"role": "system", "content": system_prompt},
                {
                    "role": "user",
                    "content": f"السياق المسترجع من المحاضرات:\n{context}\n\nسؤال الطالب: {user_message}",
                },
            ]

            response = requests.post(
                f"{self.base_url}/chat/completions",
                headers={"Authorization": f"Bearer {self.api_key}"},
                json={
                    "model": self.model,
                    "messages": messages,
                    "max_tokens": self.max_tokens,
                    "temperature": self.temperature,
                    "top_p": 0.9,
                },
                timeout=60,
            )

            if response.status_code == 200:
                result = response.json()
                return result["choices"][0]["message"]["content"].strip()
            else:
                return f"خطأ vLLM: {response.status_code} - {response.text}"

        except requests.exceptions.Timeout:
            return "خطأ: انتهاء المهلة الزمنية لطلب vLLM"
        except Exception as e:
            return f"خطأ في vLLM: {str(e)}"


class OllamaProvider(LLMProvider):
    """Ollama local LLM provider."""

    def __init__(self):
        self.base_url = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
        self.model = os.getenv("OLLAMA_MODEL", "llama2")
        self.temperature = float(os.getenv("OLLAMA_TEMPERATURE", "0.7"))

    def is_available(self) -> bool:
        """Check if Ollama server is running."""
        try:
            response = requests.get(f"{self.base_url}/api/tags", timeout=2)
            return response.status_code == 200
        except:
            return False

    def _list_available_models(self) -> list[str]:
        """Get list of available models from Ollama."""
        try:
            response = requests.get(f"{self.base_url}/api/tags", timeout=2)
            if response.status_code == 200:
                data = response.json()
                return [model["name"].split(":")[0] for model in data.get("models", [])]
            return []
        except:
            return []

    def generate(self, system_prompt: str, context: str, user_message: str) -> str:
        """Generate response using Ollama."""
        if not self.is_available():
            return "خطأ: خادم Ollama غير متاح على " + self.base_url

        try:
            # Build the full prompt
            full_prompt = f"""{system_prompt}

السياق المسترجع من المحاضرات:
{context}

سؤال الطالب: {user_message}"""

            response = requests.post(
                f"{self.base_url}/api/generate",
                json={
                    "model": self.model,
                    "prompt": full_prompt,
                    "temperature": self.temperature,
                    "stream": False,
                },
                timeout=120,
            )

            if response.status_code == 200:
                result = response.json()
                return result.get("response", "").strip()
            else:
                return f"خطأ Ollama: {response.status_code}"

        except requests.exceptions.Timeout:
            return "خطأ: انتهاء المهلة الزمنية لطلب Ollama"
        except Exception as e:
            return f"خطأ في Ollama: {str(e)}"


class LLMProviderFactory:
    """Factory to get the appropriate LLM provider."""

    @staticmethod
    def get_provider(provider_name: Optional[str] = None) -> LLMProvider:
        """Get LLM provider based on configuration or explicit name.

        Priority order if not specified:
        1. vLLM (if available)
        2. Ollama (if available)
        3. Gemini (if API key present)
        """
        if provider_name:
            if provider_name.lower() == "gemini":
                return GeminiProvider()
            elif provider_name.lower() == "vllm":
                return VLLMProvider()
            elif provider_name.lower() == "ollama":
                return OllamaProvider()
            else:
                raise ValueError(f"Unknown provider: {provider_name}")

        # Auto-detection: try local providers first, then Gemini
        vllm = VLLMProvider()
        if vllm.is_available():
            return vllm

        ollama = OllamaProvider()
        if ollama.is_available():
            return ollama

        # Fall back to Gemini
        return GeminiProvider()

    @staticmethod
    def get_available_providers() -> dict[str, bool]:
        """Check which providers are available."""
        return {
            "gemini": GeminiProvider().is_available(),
            "vllm": VLLMProvider().is_available(),
            "ollama": OllamaProvider().is_available(),
        }
