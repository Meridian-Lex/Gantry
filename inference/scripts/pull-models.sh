#!/bin/sh
# Pull required embedding and chat models into Ollama.
# Run via: docker compose -f inference/docker-compose.yml run --rm pull-models
#
# Models pulled:
#   granite-embedding:278m  768-dim cosine embeddings, Apache 2.0
#                           ~4-5 GB VRAM (FP16), top-tier MTEB score
#   llama3.2:3b             Fast chat model, default Ollama tier
#   mistral:7b              General purpose chat model
#   phi3:mini               Compact, good instruction following
#   codellama:7b            Code-specialized chat model
#
# OLLAMA_HOST must be set (injected by docker-compose or set manually).

set -e

OLLAMA="${OLLAMA_HOST:-http://localhost:11434}"

echo "Pulling granite-embedding:278m from Ollama at ${OLLAMA} ..."
ollama pull "granite-embedding:278m"
echo "Done. granite-embedding:278m is ready for use."

echo "Pulling llama3.2:3b from Ollama at ${OLLAMA} ..."
ollama pull "llama3.2:3b"
echo "Done. llama3.2:3b is ready for use."

echo "Pulling mistral:7b from Ollama at ${OLLAMA} ..."
ollama pull "mistral:7b"
echo "Done. mistral:7b is ready for use."

echo "Pulling phi3:mini from Ollama at ${OLLAMA} ..."
ollama pull "phi3:mini"
echo "Done. phi3:mini is ready for use."

echo "Pulling codellama:7b from Ollama at ${OLLAMA} ..."
ollama pull "codellama:7b"
echo "Done. codellama:7b is ready for use."
