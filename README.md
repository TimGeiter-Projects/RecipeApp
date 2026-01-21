Im Rahmen dieser Bachelorarbeit wurde eine hybride Applikation auf Basis von Dart (Flutter) entwickelt, die anhand einer Zutatenliste Rezepte generiert.

Für die KI-gestützte Verarbeitung kamen unterschiedliche Integrationsansätze zum Einsatz. Einerseits wurden vortrainierte Sprachmodelle, wie beispielsweise Qwen, direkt über die von Hugging Face bereitgestellte Inference API genutzt. Andererseits wurde für andere Modelle eine eigene REST-API auf Basis von FastAPI implementiert und in einem selbsterstellten Hugging Face Space bereitgestellt, in welcher mehrere Transformer-Modelle serverseitig ausgeführt werden.

Die KI-Modelle werden direkt im Backend geladen und ausgeführt, während die mobile Anwendung ausschließlich über HTTP-Anfragen mit der API kommuniziert. Durch die hybride Entwicklung ist die Anwendung plattformübergreifend und kann auf Android, iOS sowie im Web genutzt werden.
