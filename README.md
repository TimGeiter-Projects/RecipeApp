# KI-basierte Rezeptgenerierung

Im Rahmen dieser Bachelorarbeit wurde eine **hybride Applikation auf Basis von Dart (Flutter)** entwickelt, die anhand einer **Zutatenliste automatisch Rezepte generiert**.

## KI-gestützte Verarbeitung

Für die Rezeptgenerierung kommen unterschiedliche Integrationsansätze zum Einsatz:

- **Direkte API-Nutzung:** Vortrainierte Sprachmodelle wie **Qwen** werden direkt über die von **Hugging Face bereitgestellte Inference API** angesprochen.  
- **Eigene REST-API:** Weitere Modelle werden über eine selbst implementierte **REST-API auf Basis von FastAPI** bereitgestellt, die in einem **selbsterstellten Hugging Face Space** mehrere **Transformer-Modelle serverseitig** ausführt.

## Architektur

- Die KI-Modelle werden **direkt im Backend geladen und ausgeführt**.  
- Die mobile Anwendung kommuniziert ausschließlich über **HTTP-Anfragen** mit der API.  
- Durch die **hybride Entwicklung** ist die Anwendung **plattformübergreifend** einsetzbar: Android, iOS und Web.

## Features

- Rezeptgenerierung basierend auf einer **Zutatenliste**  
- Nutzung von **verschiedenen KI-Modellen** je nach Anwendungsfall  
- **Plattformübergreifend** einsetzbar dank Flutter  
