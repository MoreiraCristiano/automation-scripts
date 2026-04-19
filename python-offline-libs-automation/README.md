# Python Offline Libs Automation

Este projeto contém três scripts Bash para facilitar o download, instalação offline e remoção de pacotes Python em ambientes sem acesso à internet.

## Scripts disponíveis

- **download-and-compress-libs.sh**
- **install-offline-packages.sh**
- **uninstall-packages.sh**

---

## 1. download-and-compress-libs.sh

Baixa todos os pacotes especificados em um `requirements.txt` e gera um pacote compactado (`offline-packages.tar.gz`) contendo os arquivos `.whl` e o próprio `requirements.txt`.

### Uso
```bash
./download-and-compress-libs.sh requirements.txt [opções]
```

### Opções
- `--platform`           Plataforma alvo (ex: manylinux2014_x86_64)
- `--python-version`     Versão do Python (ex: 312, 311)
- `--implementation`     Implementação (default: cp)
- `--abi`                ABI (default: auto)
- `-h, --help`           Exibe ajuda

### Exemplo
```bash
./download-and-compress-libs.sh requirements.txt --platform manylinux2014_x86_64 --python-version 312
```

Ao final, será gerado o arquivo `offline-packages.tar.gz`.

---

## 2. install-offline-packages.sh

Instala pacotes Python a partir de um pacote gerado pelo script anterior, sem necessidade de acesso à internet.

### Uso
```bash
./install-offline-packages.sh caminho/do/offline-packages.tar.gz
```

- Recomenda-se executar dentro de um virtualenv.
- O script extrai o pacote, valida a estrutura e executa a instalação offline.

### Exemplo
```bash
./install-offline-packages.sh offline-packages.tar.gz
```

---

## 3. uninstall-packages.sh

Remove todos os pacotes Python instalados no ambiente atual (virtualenv ou global).

### Uso
```bash
./uninstall-packages.sh
```

- Recomenda-se executar dentro de um virtualenv para evitar afetar o Python global.
- O script solicita confirmação extra caso não esteja em um virtualenv.

### Exemplo
```bash
./uninstall-packages.sh
```

---