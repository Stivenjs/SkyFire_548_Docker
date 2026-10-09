# SkyFire 5.4.8 Docker

Entorno basado en Docker para compilar el núcleo del servidor SkyFire 5.4.8 sobre Ubuntu 24.04 con GCC 14, Boost y OpenSSL.

## Requisitos

- Docker instalado en el sistema.

## Construccion de la imagen

Para compilar la imagen utilizando la rama o referencia deseada del repositorio, ejecuta el siguiente comando:

```bash
docker build --build-arg SKYFIRE_REF=main -t skyfire548-builder .
```

### Argumentos de construccion

- `SKYFIRE_REF`: Rama, etiqueta o commit de SkyFire_548 que se clonara y compilara (por defecto: `main`).

## Uso

Una vez compilada la imagen, puedes iniciar un contenedor interactivo:

```bash
docker run -it --name skyfire-builder skyfire548-builder
```

Los binarios y archivos generados se instalan dentro del contenedor en el directorio `/opt/skyfire-server`.
