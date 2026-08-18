"""Lecture-Saver 3000: Arabic-first RAG academic assistant.

A Streamlit app that indexes PDF lectures (including scanned documents via OCR),
retrieves relevant passages using two-stage retrieval (embedding + cross-encoder
reranking), and generates cited answers using Google Gemini.
"""

import os
import re
import tempfile
from typing import Optional

import streamlit as st
import chromadb
from chromadb.utils import embedding_functions
from dotenv import load_dotenv
from pypdf import PdfReader
from sentence_transformers import CrossEncoder

# LLM provider
from llm_providers import LLMProviderFactory

# OCR imports (graceful fallback if not installed)
try:
    from pdf2image import convert_from_path
    import pytesseract

    OCR_AVAILABLE = True
except ImportError:
    OCR_AVAILABLE = False

load_dotenv()

st.set_page_config(page_title="Lecture-Saver 3000", layout="wide")

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
CHUNK_SIZE = 700
CHUNK_OVERLAP = 100
RETRIEVAL_TOP_K = 15
RERANK_TOP_K = 5
CHROMA_DB_PATH = "./streamlit_chroma_db"
COLLECTION_NAME = "academic_assistant"
EMBEDDING_MODEL = "paraphrase-multilingual-MiniLM-L12-v2"
RERANKER_MODEL = "cross-encoder/mmarco-mMiniLMv2-L12-H384-v1"
GEMINI_MODEL = "gemini-2.0-flash"
MAX_CHAT_HISTORY_TURNS = 10

SYSTEM_PROMPT = """أنت مساعد أكاديمي متخصص يساعد الطلاب في فهم محاضراتهم الجامعية.

التعليمات:
- أجب باللغة العربية فقط.
- استند فقط إلى السياق المقدم لك. إذا لم تجد الإجابة في السياق، قل ذلك بوضوح.
- وثّق كل معلومة بمصدرها باستخدام العلامات المرجعية مثل [D1]، [D2] إلخ.
- نظّم إجابتك بشكل واضح باستخدام عناوين فرعية ونقاط عند الحاجة.
- إذا طُلب منك التوضيح أو التوسع، ارجع إلى السياق المقدم لتقديم تفاصيل إضافية.
"""

# ---------------------------------------------------------------------------
# LLM Provider Initialization
# ---------------------------------------------------------------------------
# Auto-select LLM provider (priority: vLLM > Ollama > Gemini)
LLM_PROVIDER_NAME = os.environ.get("LLM_PROVIDER", "auto")
available_providers = LLMProviderFactory.get_available_providers()

if LLM_PROVIDER_NAME == "auto":
    # Find first available provider
    if available_providers["vllm"]:
        llm_provider = LLMProviderFactory.get_provider("vllm")
        provider_name = "vLLM"
    elif available_providers["ollama"]:
        llm_provider = LLMProviderFactory.get_provider("ollama")
        provider_name = "Ollama"
    elif available_providers["gemini"]:
        llm_provider = LLMProviderFactory.get_provider("gemini")
        provider_name = "Google Gemini"
    else:
        st.error("❌ لم يتم العثور على أي مزود LLM متاح!")
        st.info("""
يرجى تكوين أحد الخيارات التالية:

**خيار 1: Google Gemini (سهل للبدء)**
- أضف GEMINI_API_KEY إلى .env من https://aistudio.google.com/apikey

**خيار 2: Ollama (محلي، بدون تكاليف)**
- ثبّت Ollama من https://ollama.ai
- قم بتشغيل: ollama run llama2-arabic
- اضبط OLLAMA_MODEL و OLLAMA_BASE_URL في .env

**خيار 3: vLLM (محلي، أسرع)**
- استخدم docker-compose.yml مع خدمة vLLM
- اضبط VLLM_MODEL و VLLM_BASE_URL في .env
        """)
        st.stop()
else:
    llm_provider = LLMProviderFactory.get_provider(LLM_PROVIDER_NAME)
    provider_name = LLM_PROVIDER_NAME
    if not llm_provider.is_available():
        st.error(f"❌ مزود {provider_name} غير متاح")
        st.stop()

st.sidebar.success(f"✅ مزود LLM: {provider_name}")

# ---------------------------------------------------------------------------
# RTL Styling for Arabic UI
# ---------------------------------------------------------------------------
st.markdown("""
<style>
    .stApp, .stChatMessage, .stMarkdown, p, li, h1, h2, h3 {
        direction: rtl !important;
        text-align: right !important;
        font-family: 'Tahoma', sans-serif;
    }
    h1 { white-space: nowrap; font-size: 2.2rem !important; }
    .source-box {
        background-color: rgba(128, 128, 128, 0.1);
        color: inherit;
        border-right: 5px solid #ff4b4b;
        padding: 15px;
        margin-top: 20px;
        border-radius: 5px;
    }
    .stChatMessage { flex-direction: row-reverse !important; }
</style>
""", unsafe_allow_html=True)

st.title("📚 Lecture-Saver 3000")

# ---------------------------------------------------------------------------
# Model & Database Loading (cached across reruns)
# ---------------------------------------------------------------------------
@st.cache_resource
def load_embedding_function() -> embedding_functions.SentenceTransformerEmbeddingFunction:
    """Load the multilingual sentence embedding model."""
    return embedding_functions.SentenceTransformerEmbeddingFunction(
        model_name=EMBEDDING_MODEL
    )


@st.cache_resource
def load_reranker() -> CrossEncoder:
    """Load the cross-encoder reranking model."""
    return CrossEncoder(RERANKER_MODEL)


embedding_fn = load_embedding_function()
reranker = load_reranker()

chroma_client = chromadb.PersistentClient(path=CHROMA_DB_PATH)
collection = chroma_client.get_or_create_collection(
    name=COLLECTION_NAME,
    embedding_function=embedding_fn,
)

# ---------------------------------------------------------------------------
# Text Processing
# ---------------------------------------------------------------------------
def clean_text(raw_text: Optional[str]) -> str:
    """Remove null bytes and collapse whitespace from extracted PDF text."""
    if not raw_text:
        return ""
    text = raw_text.replace("\x00", " ")
    text = re.sub(r"[ \t]+", " ", text)
    return text.strip()


def recursive_chunk(
    text: str,
    chunk_size: int = CHUNK_SIZE,
    overlap: int = CHUNK_OVERLAP,
    separators: Optional[list[str]] = None,
) -> list[str]:
    """Split text into chunks using a hierarchy of separators, with overlap.

    Tries to split by paragraph, then by line, then by sentence boundaries
    (including Arabic punctuation), and finally by space.
    """
    if separators is None:
        separators = ["\n\n", "\n", r"(?<=[\.\!\?\u061F\u061B])\s+", " "]

    chunks = _split_recursive(text, chunk_size, separators)

    if overlap <= 0 or len(chunks) <= 1:
        return chunks

    # Add overlap: prepend the tail of the previous chunk to the current one
    overlapped = [chunks[0]]
    for i in range(1, len(chunks)):
        prev_tail = chunks[i - 1][-overlap:]
        combined = prev_tail.strip() + " " + chunks[i]
        overlapped.append(combined[:chunk_size].strip())
    return overlapped


def _split_recursive(text: str, chunk_size: int, separators: list[str]) -> list[str]:
    """Internal recursive splitting logic (no overlap applied here)."""
    if len(text) <= chunk_size:
        return [text]
    if not separators:
        return [text[i : i + chunk_size].strip() for i in range(0, len(text), chunk_size)]

    sep = separators[0]
    remaining_seps = separators[1:]

    if sep in ("\n\n", "\n", " "):
        parts = [part.strip() for part in text.split(sep) if part.strip()]
    else:
        parts = [part.strip() for part in re.split(sep, text) if part and part.strip()]

    if len(parts) <= 1:
        return _split_recursive(text, chunk_size, remaining_seps)

    # Recursively split any parts that are still too large
    refined: list[str] = []
    for part in parts:
        if len(part) > chunk_size:
            refined.extend(_split_recursive(part, chunk_size, remaining_seps))
        else:
            refined.append(part)

    # Merge small parts back together up to chunk_size
    merged: list[str] = []
    current = ""
    for part in refined:
        if not current:
            current = part
        elif len(current) + 1 + len(part) <= chunk_size:
            current += " " + part
        else:
            merged.append(current.strip())
            current = part
    if current.strip():
        merged.append(current.strip())

    return merged


# ---------------------------------------------------------------------------
# PDF Processing & Indexing
# ---------------------------------------------------------------------------
def extract_text_from_page_ocr(pdf_path: str, page_number: int) -> str:
    """Extract text from a single PDF page using OCR (for scanned documents).

    Converts the page to an image and runs Tesseract with Arabic + English support.
    """
    images = convert_from_path(pdf_path, first_page=page_number, last_page=page_number)
    if not images:
        return ""
    return pytesseract.image_to_string(images[0], lang="ara+eng")


def process_and_index_pdf(uploaded_file) -> tuple[int, int]:
    """Extract text from a PDF, chunk it, and upsert into ChromaDB.

    Uses pypdf for text extraction first. If a page yields fewer than 30
    characters and OCR is available, falls back to Tesseract OCR.

    Returns:
        A tuple of (pages_processed, chunks_indexed).
    """
    pages_processed = 0
    chunks_indexed = 0
    tmp_path = None

    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".pdf") as tmp:
            tmp.write(uploaded_file.read())
            tmp_path = tmp.name

        reader = PdfReader(tmp_path)

        for page_idx, page in enumerate(reader.pages):
            page_num = page_idx + 1
            text = clean_text(page.extract_text())

            # OCR fallback for scanned pages
            if len(text) < 30 and OCR_AVAILABLE:
                ocr_text = clean_text(extract_text_from_page_ocr(tmp_path, page_num))
                if len(ocr_text) >= 30:
                    text = ocr_text

            if len(text) < 30:
                continue

            pages_processed += 1
            chunks = recursive_chunk(text)

            for chunk_idx, chunk in enumerate(chunks):
                collection.upsert(
                    documents=[chunk],
                    metadatas=[{"source": uploaded_file.name, "page": page_num}],
                    ids=[f"{uploaded_file.name}|p{page_num}|c{chunk_idx}"],
                )
                chunks_indexed += 1

    except Exception as exc:
        st.error(f"خطأ أثناء معالجة {uploaded_file.name}: {exc}")
    finally:
        if tmp_path and os.path.exists(tmp_path):
            os.unlink(tmp_path)

    return pages_processed, chunks_indexed


# ---------------------------------------------------------------------------
# LLM Interaction
# ---------------------------------------------------------------------------
def generate_answer(context: str, user_question: str, chat_history: list[dict]) -> str:
    """Generate answer using the configured LLM provider.

    Includes recent chat history so LLM can handle follow-up questions.
    """
    # Build context with chat history (last N turns)
    recent_history = chat_history[-(MAX_CHAT_HISTORY_TURNS * 2) :]
    history_text = ""
    if recent_history:
        history_text = "\n\nسجل المحادثة السابقة:\n"
        for msg in recent_history:
            role = "الطالب" if msg["role"] == "user" else "المساعد"
            history_text += f"{role}: {msg['content']}\n"

    full_system_prompt = SYSTEM_PROMPT + history_text

    try:
        return llm_provider.generate(full_system_prompt, context, user_question)
    except Exception as exc:
        return f"عذراً، حدث خطأ أثناء توليد الإجابة: {exc}"


# ---------------------------------------------------------------------------
# Citation Processing
# ---------------------------------------------------------------------------
def process_citations(answer: str, mapping: dict[str, str]) -> tuple[str, list[str]]:
    """Replace internal document tags (D1, D2) with sequential source tags (S1, S2).

    Returns:
        A tuple of (processed_answer, unique_sources_list).
    """
    unique_sources: list[str] = []
    source_to_id: dict[str, int] = {}

    cited_numbers = re.findall(r"D(\d+)", answer)
    for num in cited_numbers:
        tag = f"D{num}"
        if tag in mapping:
            info = mapping[tag]
            if info not in source_to_id:
                unique_sources.append(info)
                source_to_id[info] = len(unique_sources)
            answer = answer.replace(tag, f"S{source_to_id[info]}")

    return answer, unique_sources


# ---------------------------------------------------------------------------
# Sidebar
# ---------------------------------------------------------------------------
with st.sidebar:
    st.header("📂 المحاضرات")

    pdf_files = st.file_uploader(
        "ارفع محاضراتك (PDF)", type="pdf", accept_multiple_files=True
    )
    if st.button("تحديث قاعدة المعرفة", use_container_width=True):
        if pdf_files:
            total_pages = 0
            total_chunks = 0
            with st.spinner("جاري المعالجة..."):
                for uploaded_file in pdf_files:
                    pages, chunks = process_and_index_pdf(uploaded_file)
                    total_pages += pages
                    total_chunks += chunks
            st.success(f"تم تحديث البيانات! ({total_pages} صفحة، {total_chunks} جزء)")
        else:
            st.warning("يرجى رفع ملف PDF أولاً.")

    if not OCR_AVAILABLE:
        st.info(
            "OCR غير متوفر. الملفات المسحوبة ضوئياً لن تُعالج.\n\n"
            "ثبّت pytesseract و pdf2image لتفعيل OCR."
        )

    st.divider()

    # Indexed documents info
    st.subheader("المستندات المفهرسة")
    try:
        indexed_count = collection.count()
        if indexed_count > 0:
            st.metric("عدد الأجزاء المفهرسة", indexed_count)
            all_metadata = collection.get(include=["metadatas"])["metadatas"]
            unique_docs = sorted({m["source"] for m in all_metadata if "source" in m})
            for doc_name in unique_docs:
                st.text(f"📄 {doc_name}")
        else:
            st.caption("لا توجد مستندات مفهرسة بعد.")
    except Exception:
        st.caption("لا توجد مستندات مفهرسة بعد.")

    st.divider()

    if st.button("🗑️ مسح المحادثة", use_container_width=True):
        st.session_state.chat_history = []
        st.rerun()

    if st.button("🗑️ مسح قاعدة المعرفة", use_container_width=True):
        chroma_client.delete_collection(COLLECTION_NAME)
        collection = chroma_client.get_or_create_collection(
            name=COLLECTION_NAME, embedding_function=embedding_fn
        )
        st.session_state.chat_history = []
        st.rerun()

# ---------------------------------------------------------------------------
# Chat Interface
# ---------------------------------------------------------------------------
if "chat_history" not in st.session_state:
    st.session_state.chat_history = []

for message in st.session_state.chat_history:
    with st.chat_message(message["role"]):
        st.markdown(message["content"])

if user_input := st.chat_input("اسألني أي سؤال عن المحاضرات..."):
    st.session_state.chat_history.append({"role": "user", "content": user_input})
    with st.chat_message("user"):
        st.markdown(user_input)

    with st.chat_message("assistant"):
        # Guard: no documents indexed yet
        if collection.count() == 0:
            answer = "لا توجد مستندات مفهرسة. يرجى رفع محاضرات أولاً من القائمة الجانبية."
            st.markdown(answer)
            st.session_state.chat_history.append({"role": "assistant", "content": answer})
        else:
            with st.spinner("جاري التفكير..."):
                # Stage 1: Broad embedding retrieval
                try:
                    results = collection.query(
                        query_texts=[user_input], n_results=RETRIEVAL_TOP_K
                    )
                    documents = results["documents"][0]
                    metadatas = results["metadatas"][0]
                except Exception as exc:
                    st.error(f"خطأ في البحث: {exc}")
                    st.stop()

                # Stage 2: Cross-encoder reranking
                pairs = [(user_input, doc) for doc in documents]
                scores = reranker.predict(pairs)
                ranked = sorted(
                    zip(scores, documents, metadatas),
                    key=lambda x: x[0],
                    reverse=True,
                )[:RERANK_TOP_K]

                # Stage 3: Build context with source mapping
                context = ""
                source_mapping: dict[str, str] = {}
                for idx, (score, doc, meta) in enumerate(ranked):
                    tag = f"D{idx + 1}"
                    context += f"[{tag}]: {doc}\n\n"
                    source_mapping[tag] = f"{meta['source']} (صفحة {meta['page']})"

                # Stage 4: Generate answer with chat history
                answer = generate_answer(
                    context, user_input, st.session_state.chat_history
                )

                # Stage 5: Process citations
                answer, unique_sources = process_citations(answer, source_mapping)

            # Display answer
            st.markdown(
                f'<div dir="rtl" style="text-align: right;">{answer}</div>',
                unsafe_allow_html=True,
            )

            # Display sources
            if unique_sources:
                source_html = '<div class="source-box" dir="rtl"><b>المصادر المعتمدة:</b><br>'
                for idx, src in enumerate(unique_sources):
                    source_html += f"{idx + 1}. {src}<br>"
                source_html += "</div>"
                st.markdown(source_html, unsafe_allow_html=True)

            st.session_state.chat_history.append(
                {"role": "assistant", "content": answer}
            )
