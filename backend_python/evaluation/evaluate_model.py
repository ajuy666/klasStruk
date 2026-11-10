"""Evaluasi hold-out untuk model LSTM tanpa mengubah artefak produksi.

Skrip ini membagi dataset menjadi data latih dan uji, lalu menyimpan metrik
serta confusion matrix pada folder ``evaluation/results``.
"""

import csv
import json
import sys
import time
from pathlib import Path

from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
)
from sklearn.model_selection import train_test_split

ROOT_DIR = Path(__file__).resolve().parents[1]
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from lstm_model import LSTMClassifier  # noqa: E402


# Parameter evaluasi setara dengan konfigurasi test_size/random_state di Colab.
DATASET_PATH = ROOT_DIR / "data" / "dataset_300.csv"
RESULTS_DIR = Path(__file__).resolve().parent / "results"
TEST_SIZE = 0.2
RANDOM_STATE = 42


def _safe_train_test_split(texts, labels):
    """Bagi data secara stratified bila setiap kategori punya minimal dua sampel."""
    label_counts = {}
    for label in labels:
        label_counts[label] = label_counts.get(label, 0) + 1

    can_stratify = all(count >= 2 for count in label_counts.values())
    stratify = labels if can_stratify else None

    return train_test_split(
        texts,
        labels,
        test_size=TEST_SIZE,
        random_state=RANDOM_STATE,
        stratify=stratify,
    )


def _write_confusion_matrix(labels, matrix):
    """Simpan tabel perbandingan label aktual dan prediksi dalam format CSV."""
    path = RESULTS_DIR / "confusion_matrix.csv"
    with path.open("w", newline="", encoding="utf-8") as file:
        writer = csv.writer(file)
        writer.writerow(["actual/predicted", *labels])
        for label, row in zip(labels, matrix):
            writer.writerow([label, *row.tolist()])


def _escape_svg(text):
    return (
        str(text)
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def _wrap_label(label, max_chars=16):
    words = str(label).replace("_", " ").split()
    lines = []
    current = ""

    for word in words:
        candidate = f"{current} {word}".strip()
        if len(candidate) <= max_chars:
            current = candidate
        else:
            if current:
                lines.append(current)
            current = word

    if current:
        lines.append(current)

    return lines or [str(label)]


def _write_confusion_matrix_svg(labels, matrix):
    cell_size = 86
    left_margin = 190
    top_margin = 150
    right_margin = 40
    bottom_margin = 60
    label_count = len(labels)
    width = left_margin + (cell_size * label_count) + right_margin
    height = top_margin + (cell_size * label_count) + bottom_margin
    max_value = max([int(value) for row in matrix for value in row] or [1])

    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        "<style>",
        "text{font-family:Arial,Helvetica,sans-serif;fill:#0f172a}",
        ".title{font-size:24px;font-weight:800}",
        ".subtitle{font-size:13px;fill:#64748b}",
        ".axis{font-size:14px;font-weight:700;fill:#334155}",
        ".label{font-size:12px;font-weight:700;fill:#334155}",
        ".value{font-size:20px;font-weight:800}",
        ".small{font-size:11px;fill:#64748b}",
        "</style>",
        '<rect width="100%" height="100%" fill="#f8fafc"/>',
        f'<text x="{left_margin}" y="42" class="title">Confusion Matrix LSTM</text>',
        f'<text x="{left_margin}" y="66" class="subtitle">Aktual di sisi kiri, prediksi di bagian atas</text>',
        f'<text x="{left_margin + (cell_size * label_count / 2)}" y="106" text-anchor="middle" class="axis">Prediksi</text>',
        f'<text x="34" y="{top_margin + (cell_size * label_count / 2)}" text-anchor="middle" class="axis" transform="rotate(-90 34 {top_margin + (cell_size * label_count / 2)})">Aktual</text>',
    ]

    for index, label in enumerate(labels):
        center_x = left_margin + (index * cell_size) + (cell_size / 2)
        label_lines = _wrap_label(label)
        first_y = top_margin - 56 - ((len(label_lines) - 1) * 7)
        for line_index, line in enumerate(label_lines):
            parts.append(
                f'<text x="{center_x}" y="{first_y + (line_index * 14)}" text-anchor="middle" class="label">{_escape_svg(line)}</text>'
            )

        center_y = top_margin + (index * cell_size) + (cell_size / 2)
        row_lines = _wrap_label(label, max_chars=18)
        first_row_y = center_y - ((len(row_lines) - 1) * 7)
        for line_index, line in enumerate(row_lines):
            parts.append(
                f'<text x="{left_margin - 18}" y="{first_row_y + (line_index * 14)}" text-anchor="end" class="label">{_escape_svg(line)}</text>'
            )

    for row_index, row in enumerate(matrix):
        for col_index, value in enumerate(row):
            x = left_margin + (col_index * cell_size)
            y = top_margin + (row_index * cell_size)
            intensity = 0 if max_value == 0 else int(value) / max_value
            blue = 245 - int(125 * intensity)
            green = 250 - int(86 * intensity)
            red = 239 - int(202 * intensity)
            text_color = "#ffffff" if intensity >= 0.62 else "#0f172a"

            parts.extend(
                [
                    f'<rect x="{x}" y="{y}" width="{cell_size}" height="{cell_size}" rx="10" fill="rgb({red},{green},{blue})" stroke="#ffffff" stroke-width="3"/>',
                    f'<text x="{x + (cell_size / 2)}" y="{y + 44}" text-anchor="middle" class="value" fill="{text_color}">{int(value)}</text>',
                    f'<text x="{x + (cell_size / 2)}" y="{y + 63}" text-anchor="middle" class="small" fill="{text_color}">data</text>',
                ]
            )

    parts.append("</svg>")
    (RESULTS_DIR / "confusion_matrix.svg").write_text(
        "\n".join(parts) + "\n", encoding="utf-8"
    )


def _write_classification_report(report):
    path = RESULTS_DIR / "classification_report.csv"
    fieldnames = ["label", "precision", "recall", "f1_score", "support"]

    with path.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=fieldnames)
        writer.writeheader()

        for label, values in report.items():
            if not isinstance(values, dict):
                continue

            writer.writerow(
                {
                    "label": label,
                    "precision": values.get("precision", ""),
                    "recall": values.get("recall", ""),
                    "f1_score": values.get("f1-score", ""),
                    "support": values.get("support", ""),
                }
            )


def _write_predictions(texts, actual, predicted):
    path = RESULTS_DIR / "test_predictions.csv"
    with path.open("w", newline="", encoding="utf-8") as file:
        writer = csv.writer(file)
        writer.writerow(["text", "actual_category", "predicted_category", "is_correct"])
        for text, actual_label, predicted_label in zip(texts, actual, predicted):
            writer.writerow(
                [text, actual_label, predicted_label, actual_label == predicted_label]
            )


def _write_markdown(summary, labels, matrix):
    path = RESULTS_DIR / "metrics.md"
    lines = [
        "# Hasil Evaluasi LSTM",
        "",
        "## Ringkasan",
        "",
        f"- Dataset: `{summary['dataset_path']}`",
        f"- Total data: {summary['dataset_size']}",
        f"- Data training: {summary['train_size']}",
        f"- Data testing: {summary['test_size']}",
        f"- Test split: {summary['test_split_percent']}%",
        f"- Random state: {summary['random_state']}",
        "",
        "## Metrik",
        "",
        f"- Accuracy: {summary['accuracy_percent']}%",
        f"- Precision macro: {summary['precision_macro_percent']}%",
        f"- Recall macro: {summary['recall_macro_percent']}%",
        f"- F1-score macro: {summary['f1_macro_percent']}%",
        f"- F1-score weighted: {summary['f1_weighted_percent']}%",
        "",
        "## Performa",
        "",
        f"- Waktu training: {summary['training_time_seconds']} detik",
        f"- Waktu prediksi total: {summary['prediction_time_seconds']} detik",
        f"- Rata-rata waktu prediksi per item: {summary['avg_prediction_time_ms']} ms",
        "",
        "## Confusion Matrix",
        "",
        "| Aktual \\ Prediksi | " + " | ".join(labels) + " |",
        "|---|" + "|".join(["---"] * len(labels)) + "|",
    ]

    for label, row in zip(labels, matrix):
        lines.append("| " + label + " | " + " | ".join(map(str, row.tolist())) + " |")

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main():
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)

    classifier = LSTMClassifier()
    texts, labels = classifier.load_dataset(str(DATASET_PATH))
    x_train, x_test, y_train, y_test = _safe_train_test_split(texts, labels)

    train_start = time.perf_counter()
    classifier.fit(x_train, y_train, epochs=20)
    training_time = time.perf_counter() - train_start

    predict_start = time.perf_counter()
    y_pred = classifier.predict_many(x_test)
    prediction_time = time.perf_counter() - predict_start

    sorted_labels = sorted(set(labels))
    matrix = confusion_matrix(y_test, y_pred, labels=sorted_labels)
    report = classification_report(
        y_test,
        y_pred,
        labels=sorted_labels,
        output_dict=True,
        zero_division=0,
    )

    summary = {
        "dataset_path": str(DATASET_PATH),
        "dataset_size": len(texts),
        "train_size": len(x_train),
        "test_size": len(x_test),
        "test_split_percent": int(TEST_SIZE * 100),
        "random_state": RANDOM_STATE,
        "accuracy": accuracy_score(y_test, y_pred),
        "accuracy_percent": round(accuracy_score(y_test, y_pred) * 100, 2),
        "precision_macro": precision_score(
            y_test, y_pred, average="macro", zero_division=0
        ),
        "precision_macro_percent": round(
            precision_score(y_test, y_pred, average="macro", zero_division=0) * 100,
            2,
        ),
        "recall_macro": recall_score(y_test, y_pred, average="macro", zero_division=0),
        "recall_macro_percent": round(
            recall_score(y_test, y_pred, average="macro", zero_division=0) * 100, 2
        ),
        "f1_macro": f1_score(y_test, y_pred, average="macro", zero_division=0),
        "f1_macro_percent": round(
            f1_score(y_test, y_pred, average="macro", zero_division=0) * 100, 2
        ),
        "f1_weighted": f1_score(y_test, y_pred, average="weighted", zero_division=0),
        "f1_weighted_percent": round(
            f1_score(y_test, y_pred, average="weighted", zero_division=0) * 100, 2
        ),
        "training_time_seconds": round(training_time, 6),
        "prediction_time_seconds": round(prediction_time, 6),
        "avg_prediction_time_ms": round((prediction_time / len(x_test)) * 1000, 6)
        if x_test
        else 0,
    }

    (RESULTS_DIR / "summary.json").write_text(
        json.dumps(summary, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    _write_confusion_matrix(sorted_labels, matrix)
    _write_confusion_matrix_svg(sorted_labels, matrix)
    _write_classification_report(report)
    _write_predictions(x_test, y_test, y_pred)
    _write_markdown(summary, sorted_labels, matrix)

    print("Evaluasi selesai.")
    print(f"Accuracy: {summary['accuracy_percent']}%")
    print(f"F1-score macro: {summary['f1_macro_percent']}%")
    print(f"Hasil disimpan di: {RESULTS_DIR}")


if __name__ == "__main__":
    main()
