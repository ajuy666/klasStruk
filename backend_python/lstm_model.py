"""LSTM classifier untuk kategori produk hasil OCR.

Model menerima urutan kata dari nama produk, lalu mengembalikan kategori dan
confidence. Tokenizer serta label encoder dibuat dari dataset saat training,
sehingga istilah produk baru tetap dapat diproses sebagai token OOV.
"""

import csv
import json
import os
import random

import numpy as np
import tensorflow as tf
from sklearn.preprocessing import LabelEncoder
from nlp_preprocessing import preprocess_text


class LSTMClassifier:
    """Latih, simpan, muat, dan gunakan model kategori produk.

    Parameter arsitektur berada di konstruktor agar setara dengan CONFIG pada
    notebook Colab. Artefak hasil training disimpan pada folder ``models``.
    """
    MODEL_VERSION = 3
    # Prediksi yang kurang dari 50% tidak cukup aman untuk langsung
    # dimasukkan ke kategori spesifik.
    MIN_CONFIDENCE = 0.50

    def __init__(
        self,
        max_words: int = 2000,
        max_length: int = 12,
        embedding_dim: int = 32,
        lstm_units: int = 32,
    ):
        self.max_words = max_words
        self.max_length = max_length
        self.embedding_dim = embedding_dim
        self.lstm_units = lstm_units
        self.tokenizer = tf.keras.preprocessing.text.Tokenizer(
            num_words=max_words,
            oov_token="<OOV>",
            lower=True,
        )
        self.label_encoder = LabelEncoder()
        self.model = None
        self.trained = False

    @property
    def _artifact_dir(self):
        return os.path.join(os.path.dirname(os.path.abspath(__file__)), "models")

    @property
    def _model_path(self):
        return os.path.join(self._artifact_dir, "product_category_lstm.keras")

    @property
    def _metadata_path(self):
        return os.path.join(self._artifact_dir, "product_category_lstm.json")

    def load_dataset(self, path: str):
        texts, labels = [], []
        if not os.path.exists(path):
            raise FileNotFoundError(f"Dataset tidak ditemukan: {path}")

        with open(path, "r", encoding="utf-8") as file:
            for row in csv.DictReader(file):
                # Samakan bentuk teks latih dengan nama hasil OCR/Gemini yang
                # diproses sebelum masuk ke LSTM saat prediksi.
                text = preprocess_text(str(row.get("text", "")).strip())
                category = str(row.get("category", "")).strip()
                if text and category:
                    texts.append(text)
                    labels.append(category)

        if not texts:
            raise ValueError("Dataset kosong atau format kolom text/category tidak valid.")
        return texts, labels

    def train(self, path: str = None, epochs: int = 20, verbose: int = 0):
        if path is None:
            base_dir = os.path.dirname(os.path.abspath(__file__))
            path = os.path.join(base_dir, "data", "dataset_300.csv")

        if self._can_load_saved_model(path):
            self._load_saved_model()
            print("Model LSTM tersimpan berhasil dimuat")
            return

        texts, labels = self.load_dataset(path)
        self.fit(texts, labels, epochs=epochs, verbose=verbose)
        self._save_model()
        print(f"LSTM berhasil dilatih dari: {path}")
        print(f"Total data training: {len(texts)}")

    def fit(self, texts: list[str], labels: list[str], epochs: int = 20, verbose: int = 0):
        """Latih model dari data in-memory; dipakai juga oleh evaluasi hold-out."""
        if not texts or not labels:
            raise ValueError("Data training LSTM tidak boleh kosong.")

        # Hasil training konsisten saat backend dijalankan ulang.
        random.seed(42)
        np.random.seed(42)
        tf.keras.utils.set_random_seed(42)

        normalized_texts = [preprocess_text(text) or "unknown" for text in texts]
        self.tokenizer.fit_on_texts(normalized_texts)
        x_train = self._to_sequences(normalized_texts)
        y_train = self.label_encoder.fit_transform(labels)
        class_count = len(self.label_encoder.classes_)

        self.model = tf.keras.Sequential([
            tf.keras.layers.Input(shape=(self.max_length,)),
            tf.keras.layers.Embedding(
                input_dim=min(self.max_words, len(self.tokenizer.word_index) + 1),
                output_dim=self.embedding_dim,
                mask_zero=True,
            ),
            # Arsitektur disamakan dengan notebook Colab: LSTM satu arah
            # biasa, bukan Bidirectional LSTM.
            tf.keras.layers.LSTM(self.lstm_units),
            tf.keras.layers.Dropout(0.2),
            tf.keras.layers.Dense(class_count, activation="softmax"),
        ])
        self.model.compile(
            optimizer="adam",
            loss="sparse_categorical_crossentropy",
            metrics=["accuracy"],
        )
        self.model.fit(
            x_train,
            y_train,
            epochs=epochs,
            batch_size=16,
            verbose=verbose,
        )
        self.trained = True

    @staticmethod
    def _is_standard_lstm(model) -> bool:
        """Pastikan artefak memakai LSTM biasa seperti notebook Colab."""
        layers = model.layers
        return (
            any(isinstance(layer, tf.keras.layers.LSTM) for layer in layers)
            and not any(
                isinstance(layer, tf.keras.layers.Bidirectional) for layer in layers
            )
        )

    def _can_load_saved_model(self, dataset_path: str) -> bool:
        """Pakai artefak yang versinya cocok, terbaru, dan berarsitektur LSTM biasa."""
        if not (os.path.exists(self._model_path) and os.path.exists(self._metadata_path)):
            return False
        with open(self._metadata_path, "r", encoding="utf-8") as file:
            metadata = json.load(file)
        if (
            metadata.get("model_version") != self.MODEL_VERSION
            or os.path.getmtime(self._model_path) < os.path.getmtime(dataset_path)
        ):
            return False

        try:
            saved_model = tf.keras.models.load_model(self._model_path)
        except (OSError, ValueError):
            return False
        return self._is_standard_lstm(saved_model)

    def _save_model(self):
        """Simpan jaringan Keras serta tokenizer/label encoder pendukungnya."""
        os.makedirs(self._artifact_dir, exist_ok=True)
        self.model.save(self._model_path)
        metadata = {
            "model_version": self.MODEL_VERSION,
            "max_words": self.max_words,
            "max_length": self.max_length,
            "tokenizer": self.tokenizer.to_json(),
            "classes": self.label_encoder.classes_.tolist(),
        }
        with open(self._metadata_path, "w", encoding="utf-8") as file:
            json.dump(metadata, file, ensure_ascii=False)

    def _load_saved_model(self):
        """Pulihkan model dan metadata agar prediksi konsisten dengan training."""
        with open(self._metadata_path, "r", encoding="utf-8") as file:
            metadata = json.load(file)
        self.max_words = int(metadata["max_words"])
        self.max_length = int(metadata["max_length"])
        self.tokenizer = tf.keras.preprocessing.text.tokenizer_from_json(
            metadata["tokenizer"]
        )
        self.label_encoder.classes_ = np.array(metadata["classes"])
        self.model = tf.keras.models.load_model(self._model_path)
        self.trained = True

    def _to_sequences(self, texts):
        normalized_texts = [
            preprocess_text(str(text)) or "unknown" for text in texts
        ]
        sequences = self.tokenizer.texts_to_sequences(normalized_texts)
        return tf.keras.preprocessing.sequence.pad_sequences(
            sequences,
            maxlen=self.max_length,
            padding="post",
            truncating="post",
        )

    def predict(self, text: str) -> str:
        return self.predict_with_confidence(text)["category"]

    def predict_with_confidence(self, text: str) -> dict:
        """Prediksi kategori; confidence rendah dikembalikan sebagai ``lainnya``."""
        if not self.trained or self.model is None or not str(text).strip():
            return {"category": "lainnya", "confidence": 0.0}

        probabilities = self.model.predict(self._to_sequences([text]), verbose=0)[0]
        category_index = int(np.argmax(probabilities))
        confidence = float(probabilities[category_index])
        category = str(self.label_encoder.inverse_transform([category_index])[0])
        return {
            "category": category if confidence >= self.MIN_CONFIDENCE else "lainnya",
            "confidence": confidence,
        }

    def predict_many(self, texts: list[str]) -> list[str]:
        if not self.trained or self.model is None:
            return ["lainnya" for _ in texts]
        probabilities = self.model.predict(self._to_sequences(texts), verbose=0)
        indexes = np.argmax(probabilities, axis=1)
        return [str(value) for value in self.label_encoder.inverse_transform(indexes)]
