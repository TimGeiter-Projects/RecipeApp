# KI-basierte Rezeptgenerierung

Im Rahmen dieser Bachelorarbeit wurde eine **hybride Applikation auf Basis von Dart (Flutter)** entwickelt, die anhand einer **Zutatenliste automatisch Rezepte generiert**.


## Tech Stack
**Frontend:** Dart & Flutter (Cross-Platform UI für Android, iOS & Web)

**Frontend-Logik:** Lokale Datenhaltung via Shared Preferences (Caching & User Settings)

**Backend:** Python & FastAPI (REST-API zur Steuerung der KI-Logik)

**KI & NLP:** Hugging Face (Transformers-Library, Qwen LLM via Inference API)

**Infrastruktur:** Docker (Containerisierung), Hugging Face Spaces (Cloud-Hosting)

**Kommunikation:** REST (HTTP/JSON) (Anbindung zwischen Mobile-App und Backend)




## KI-gestützte Verarbeitung

Für die Rezeptgenerierung kommen unterschiedliche Integrationsansätze zum Einsatz:

- **Direkte API-Nutzung:** Vortrainierte Sprachmodelle wie **Qwen** werden direkt über die von **Hugging Face bereitgestellte Inference API** angesprochen.  
- **Eigene REST-API:** Weitere Modelle werden über eine selbst implementierte **REST-API auf Basis von FastAPI** bereitgestellt, die in einem **selbsterstellten Hugging Face Space** mehrere **Transformer-Modelle serverseitig** ausführt (https://huggingface.co/spaces/TimInf/DockerRecipe).

## Architektur

- Die KI-Modelle werden **direkt im Backend geladen und ausgeführt**.  
- Die mobile Anwendung kommuniziert ausschließlich über **HTTP-Anfragen** mit der API.  
- Durch die **hybride Entwicklung** ist die Anwendung **plattformübergreifend** einsetzbar: Android, iOS und Web.

## Features

- Rezeptgenerierung basierend auf einer **Zutatenliste**  
- Nutzung von **verschiedenen KI-Modellen** je nach Anwendungsfall  
- **Plattformübergreifend** einsetzbar dank Flutter  
