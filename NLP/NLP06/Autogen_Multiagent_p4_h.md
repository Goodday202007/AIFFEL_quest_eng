# Multi Agent : Autogen 실습 : StockAgent  
삼성전자와 SK하이닉스 주식 성과를 비교해서 투자 관련 참고 의견만 제공

#### 파이프라인

1. 주가 metrics (2년치 삼성전자, SK 하이닉스 주가)
2. 가상의 삼성 뉴스(3개) + 하이닉스 뉴스(3개) -> News Agent가 이를 기반으로 하여 애널리스트 리포트를 작성한다
3. 삼성전자 Agent, 하이닉스 Agent : 주가 metrics + 뉴스 기반 리포트를 기반으로 하여 투자 의견 작성한다
4. Decision Agent가 삼성전자 Agent와 하이닉스 Agent가 작성한 애널리스트 리포트를 근거로 판단한다

### Hugging Face Token 등록


```python
from google.colab import drive
drive.mount('/content/drive')
```

    Mounted at /content/drive
    


```python
%cd /content/drive/MyDrive/aiffel/3.rag/4
```

    /content/drive/MyDrive/aiffel/3.rag/4
    


```python
from dotenv import load_dotenv
import os

# load_dotenv("/content/drive/MyDrive/aiffel/env_keys/.env")
load_dotenv(".env")


print("HF_TOKEN loaded:", os.getenv("HF_TOKEN") is not None)
HF_TOKEN      = os.getenv("HF_TOKEN")

print("OPENAI_API_KEY loaded:", os.getenv("OPENAI_API_KEY") is not None)
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
```

    HF_TOKEN loaded: True
    OPENAI_API_KEY loaded: True
    

### 주가 갖고오는 프로그램


```python
!pip install pykrx
```

    Requirement already satisfied: pykrx in /usr/local/lib/python3.12/dist-packages (1.2.4)
    Requirement already satisfied: requests>=2.32.0 in /usr/local/lib/python3.12/dist-packages (from pykrx) (2.32.4)
    Requirement already satisfied: pandas<3.0,>=2.2.0 in /usr/local/lib/python3.12/dist-packages (from pykrx) (2.2.2)
    Requirement already satisfied: numpy<2.0,>=1.24.0 in /usr/local/lib/python3.12/dist-packages (from pykrx) (1.26.4)
    Requirement already satisfied: deprecated>=1.2.14 in /usr/local/lib/python3.12/dist-packages (from pykrx) (1.3.1)
    Requirement already satisfied: multipledispatch>=1.0.0 in /usr/local/lib/python3.12/dist-packages (from pykrx) (1.0.0)
    Requirement already satisfied: matplotlib>=3.8.0 in /usr/local/lib/python3.12/dist-packages (from pykrx) (3.10.0)
    Requirement already satisfied: wrapt<3,>=1.10 in /usr/local/lib/python3.12/dist-packages (from deprecated>=1.2.14->pykrx) (2.1.2)
    Requirement already satisfied: contourpy>=1.0.1 in /usr/local/lib/python3.12/dist-packages (from matplotlib>=3.8.0->pykrx) (1.3.3)
    Requirement already satisfied: cycler>=0.10 in /usr/local/lib/python3.12/dist-packages (from matplotlib>=3.8.0->pykrx) (0.12.1)
    Requirement already satisfied: fonttools>=4.22.0 in /usr/local/lib/python3.12/dist-packages (from matplotlib>=3.8.0->pykrx) (4.62.1)
    Requirement already satisfied: kiwisolver>=1.3.1 in /usr/local/lib/python3.12/dist-packages (from matplotlib>=3.8.0->pykrx) (1.5.0)
    Requirement already satisfied: packaging>=20.0 in /usr/local/lib/python3.12/dist-packages (from matplotlib>=3.8.0->pykrx) (26.0)
    Requirement already satisfied: pillow>=8 in /usr/local/lib/python3.12/dist-packages (from matplotlib>=3.8.0->pykrx) (11.3.0)
    Requirement already satisfied: pyparsing>=2.3.1 in /usr/local/lib/python3.12/dist-packages (from matplotlib>=3.8.0->pykrx) (3.3.2)
    Requirement already satisfied: python-dateutil>=2.7 in /usr/local/lib/python3.12/dist-packages (from matplotlib>=3.8.0->pykrx) (2.9.0.post0)
    Requirement already satisfied: pytz>=2020.1 in /usr/local/lib/python3.12/dist-packages (from pandas<3.0,>=2.2.0->pykrx) (2025.2)
    Requirement already satisfied: tzdata>=2022.7 in /usr/local/lib/python3.12/dist-packages (from pandas<3.0,>=2.2.0->pykrx) (2025.3)
    Requirement already satisfied: charset_normalizer<4,>=2 in /usr/local/lib/python3.12/dist-packages (from requests>=2.32.0->pykrx) (3.4.6)
    Requirement already satisfied: idna<4,>=2.5 in /usr/local/lib/python3.12/dist-packages (from requests>=2.32.0->pykrx) (3.11)
    Requirement already satisfied: urllib3<3,>=1.21.1 in /usr/local/lib/python3.12/dist-packages (from requests>=2.32.0->pykrx) (2.5.0)
    Requirement already satisfied: certifi>=2017.4.17 in /usr/local/lib/python3.12/dist-packages (from requests>=2.32.0->pykrx) (2026.2.25)
    Requirement already satisfied: six>=1.5 in /usr/local/lib/python3.12/dist-packages (from python-dateutil>=2.7->matplotlib>=3.8.0->pykrx) (1.17.0)
    


```python
from pykrx import stock
import pandas as pd
import numpy as np
```


```python
def compute_metrics(df, price_col="Close", risk_free_rate=0.0, freq=252):
    """가격 시계열 df에서 수익률, 변동성, MDD, Sharpe 등을 계산."""
    # 1. 가격 → 일간 수익률 계산
    r = df[price_col].pct_change().dropna()

    # 2. 연간화 수익률, 변동성
    annual_return = r.mean() * freq
    annual_vol = r.std() * np.sqrt(freq)

    # 3. 최대 낙폭(Maximum Drawdown, MDD)
    cum_ret = (1 + r).cumprod()
    cum_max = cum_ret.cummax()
    drawdown = (cum_ret - cum_max) / cum_max
    max_drawdown = drawdown.min()

    # 4. Sharpe ratio (무위험수익률 0 가정)
    excess_return = annual_return - risk_free_rate
    sharpe = excess_return / annual_vol if annual_vol > 1e-8 else np.nan

    # 5. 기하 평균 수익률 (CAGR)
    cagr = cum_ret.iloc[-1] ** (freq / len(r)) - 1

    # 6. 결과 딕셔너리로 반환
    metrics = {
        "annual_return": annual_return,
        "annual_volatility": annual_vol,
        "max_drawdown": max_drawdown,
        "sharpe_ratio": sharpe,
        "cagr": cagr,
        "n_days": len(r)
    }
    return pd.Series(metrics)

```


```python
# 1) 과거 주가 가져오는 함수
def fetch_stock_history(ticker: str, years: int = 2) -> pd.DataFrame:
    end = pd.Timestamp.today().strftime("%Y%m%d")
    start = (pd.Timestamp.today() - pd.DateOffset(years=years)).strftime("%Y%m%d")
    df = stock.get_market_ohlcv(start, end, ticker)
    return df
```


```python
# 2) 하나의 종목에 대해 compute_metrics 적용하는 래퍼
def compute_stock_metrics_for_ticker(ticker: str, years: int = 2) -> pd.Series:
    df = fetch_stock_history(ticker, years=years)
    # compute_metrics는 Close 컬럼 기준이라고 가정
    metrics = compute_metrics(df.rename(columns={"종가": "Close"}))
    return metrics
```


```python
# 3) 두 종목을 한 번에 계산 (decisionAgent에 넘길 payload)
def compute_pair_metrics(t1: str = "005930", t2: str = "000660", years: int = 2):
    m1 = compute_stock_metrics_for_ticker(t1, years=years)
    m2 = compute_stock_metrics_for_ticker(t2, years=years)
    return {
        t1: m1.to_dict(),
        t2: m2.to_dict(),
    }
```


```python

```

### Step 0 : 설치와 준비  
Autogen 설치 및 Gemini API 키를 등록하도록 합니다.


```python
!pip install autogen
!pip install -U "autogen-agentchat"
!pip install "autogen-ext[openai]"
```

    Collecting autogen
      Downloading autogen-0.11.4-py3-none-any.whl.metadata (24 kB)
    Collecting ag2==0.11.4 (from autogen)
      Downloading ag2-0.11.4-py3-none-any.whl.metadata (38 kB)
    Requirement already satisfied: anyio<5.0.0,>=4.0.0 in /usr/local/lib/python3.12/dist-packages (from ag2==0.11.4->autogen) (4.12.1)
    Collecting diskcache (from ag2==0.11.4->autogen)
      Downloading diskcache-5.6.3-py3-none-any.whl.metadata (20 kB)
    Collecting docker (from ag2==0.11.4->autogen)
      Downloading docker-7.1.0-py3-none-any.whl.metadata (3.8 kB)
    Collecting fast-depends<4.0.0,>=3.0.8 (from fast-depends[pydantic]<4.0.0,>=3.0.8->ag2==0.11.4->autogen)
      Downloading fast_depends-3.0.8-py3-none-any.whl.metadata (7.7 kB)
    Requirement already satisfied: httpx<1,>=0.28.1 in /usr/local/lib/python3.12/dist-packages (from ag2==0.11.4->autogen) (0.28.1)
    Requirement already satisfied: packaging in /usr/local/lib/python3.12/dist-packages (from ag2==0.11.4->autogen) (26.0)
    Requirement already satisfied: pydantic<3,>=2.6.1 in /usr/local/lib/python3.12/dist-packages (from ag2==0.11.4->autogen) (2.12.3)
    Requirement already satisfied: python-dotenv in /usr/local/lib/python3.12/dist-packages (from ag2==0.11.4->autogen) (1.2.2)
    Requirement already satisfied: termcolor in /usr/local/lib/python3.12/dist-packages (from ag2==0.11.4->autogen) (3.3.0)
    Requirement already satisfied: tiktoken in /usr/local/lib/python3.12/dist-packages (from ag2==0.11.4->autogen) (0.12.0)
    Requirement already satisfied: idna>=2.8 in /usr/local/lib/python3.12/dist-packages (from anyio<5.0.0,>=4.0.0->ag2==0.11.4->autogen) (3.11)
    Requirement already satisfied: typing_extensions>=4.5 in /usr/local/lib/python3.12/dist-packages (from anyio<5.0.0,>=4.0.0->ag2==0.11.4->autogen) (4.15.0)
    Requirement already satisfied: certifi in /usr/local/lib/python3.12/dist-packages (from httpx<1,>=0.28.1->ag2==0.11.4->autogen) (2026.2.25)
    Requirement already satisfied: httpcore==1.* in /usr/local/lib/python3.12/dist-packages (from httpx<1,>=0.28.1->ag2==0.11.4->autogen) (1.0.9)
    Requirement already satisfied: h11>=0.16 in /usr/local/lib/python3.12/dist-packages (from httpcore==1.*->httpx<1,>=0.28.1->ag2==0.11.4->autogen) (0.16.0)
    Requirement already satisfied: annotated-types>=0.6.0 in /usr/local/lib/python3.12/dist-packages (from pydantic<3,>=2.6.1->ag2==0.11.4->autogen) (0.7.0)
    Requirement already satisfied: pydantic-core==2.41.4 in /usr/local/lib/python3.12/dist-packages (from pydantic<3,>=2.6.1->ag2==0.11.4->autogen) (2.41.4)
    Requirement already satisfied: typing-inspection>=0.4.2 in /usr/local/lib/python3.12/dist-packages (from pydantic<3,>=2.6.1->ag2==0.11.4->autogen) (0.4.2)
    Requirement already satisfied: requests>=2.26.0 in /usr/local/lib/python3.12/dist-packages (from docker->ag2==0.11.4->autogen) (2.32.4)
    Requirement already satisfied: urllib3>=1.26.0 in /usr/local/lib/python3.12/dist-packages (from docker->ag2==0.11.4->autogen) (2.5.0)
    Requirement already satisfied: regex>=2022.1.18 in /usr/local/lib/python3.12/dist-packages (from tiktoken->ag2==0.11.4->autogen) (2025.11.3)
    Requirement already satisfied: charset_normalizer<4,>=2 in /usr/local/lib/python3.12/dist-packages (from requests>=2.26.0->docker->ag2==0.11.4->autogen) (3.4.6)
    Downloading autogen-0.11.4-py3-none-any.whl (13 kB)
    Downloading ag2-0.11.4-py3-none-any.whl (1.1 MB)
    [2K   [90m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━[0m [32m1.1/1.1 MB[0m [31m49.7 MB/s[0m eta [36m0:00:00[0m
    [?25hDownloading fast_depends-3.0.8-py3-none-any.whl (25 kB)
    Downloading diskcache-5.6.3-py3-none-any.whl (45 kB)
    [2K   [90m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━[0m [32m45.5/45.5 kB[0m [31m5.4 MB/s[0m eta [36m0:00:00[0m
    [?25hDownloading docker-7.1.0-py3-none-any.whl (147 kB)
    [2K   [90m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━[0m [32m147.8/147.8 kB[0m [31m18.1 MB/s[0m eta [36m0:00:00[0m
    [?25hInstalling collected packages: diskcache, fast-depends, docker, ag2, autogen
    Successfully installed ag2-0.11.4 autogen-0.11.4 diskcache-5.6.3 docker-7.1.0 fast-depends-3.0.8
    Collecting autogen-agentchat
      Downloading autogen_agentchat-0.7.5-py3-none-any.whl.metadata (2.5 kB)
    Collecting autogen-core==0.7.5 (from autogen-agentchat)
      Downloading autogen_core-0.7.5-py3-none-any.whl.metadata (2.3 kB)
    Collecting jsonref~=1.1.0 (from autogen-core==0.7.5->autogen-agentchat)
      Downloading jsonref-1.1.0-py3-none-any.whl.metadata (2.7 kB)
    Requirement already satisfied: opentelemetry-api>=1.34.1 in /usr/local/lib/python3.12/dist-packages (from autogen-core==0.7.5->autogen-agentchat) (1.38.0)
    Requirement already satisfied: pillow>=11.0.0 in /usr/local/lib/python3.12/dist-packages (from autogen-core==0.7.5->autogen-agentchat) (11.3.0)
    Requirement already satisfied: protobuf~=5.29.3 in /usr/local/lib/python3.12/dist-packages (from autogen-core==0.7.5->autogen-agentchat) (5.29.6)
    Requirement already satisfied: pydantic<3.0.0,>=2.10.0 in /usr/local/lib/python3.12/dist-packages (from autogen-core==0.7.5->autogen-agentchat) (2.12.3)
    Requirement already satisfied: typing-extensions>=4.0.0 in /usr/local/lib/python3.12/dist-packages (from autogen-core==0.7.5->autogen-agentchat) (4.15.0)
    Requirement already satisfied: importlib-metadata<8.8.0,>=6.0 in /usr/local/lib/python3.12/dist-packages (from opentelemetry-api>=1.34.1->autogen-core==0.7.5->autogen-agentchat) (8.7.1)
    Requirement already satisfied: annotated-types>=0.6.0 in /usr/local/lib/python3.12/dist-packages (from pydantic<3.0.0,>=2.10.0->autogen-core==0.7.5->autogen-agentchat) (0.7.0)
    Requirement already satisfied: pydantic-core==2.41.4 in /usr/local/lib/python3.12/dist-packages (from pydantic<3.0.0,>=2.10.0->autogen-core==0.7.5->autogen-agentchat) (2.41.4)
    Requirement already satisfied: typing-inspection>=0.4.2 in /usr/local/lib/python3.12/dist-packages (from pydantic<3.0.0,>=2.10.0->autogen-core==0.7.5->autogen-agentchat) (0.4.2)
    Requirement already satisfied: zipp>=3.20 in /usr/local/lib/python3.12/dist-packages (from importlib-metadata<8.8.0,>=6.0->opentelemetry-api>=1.34.1->autogen-core==0.7.5->autogen-agentchat) (3.23.0)
    Downloading autogen_agentchat-0.7.5-py3-none-any.whl (119 kB)
    [2K   [90m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━[0m [32m119.3/119.3 kB[0m [31m11.3 MB/s[0m eta [36m0:00:00[0m
    [?25hDownloading autogen_core-0.7.5-py3-none-any.whl (101 kB)
    [2K   [90m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━[0m [32m101.9/101.9 kB[0m [31m14.0 MB/s[0m eta [36m0:00:00[0m
    [?25hDownloading jsonref-1.1.0-py3-none-any.whl (9.4 kB)
    Installing collected packages: jsonref, autogen-core, autogen-agentchat
    Successfully installed autogen-agentchat-0.7.5 autogen-core-0.7.5 jsonref-1.1.0
    Collecting autogen-ext[openai]
      Downloading autogen_ext-0.7.5-py3-none-any.whl.metadata (7.3 kB)
    Requirement already satisfied: autogen-core==0.7.5 in /usr/local/lib/python3.12/dist-packages (from autogen-ext[openai]) (0.7.5)
    Requirement already satisfied: aiofiles in /usr/local/lib/python3.12/dist-packages (from autogen-ext[openai]) (24.1.0)
    Requirement already satisfied: openai>=1.93 in /usr/local/lib/python3.12/dist-packages (from autogen-ext[openai]) (2.28.0)
    Requirement already satisfied: tiktoken>=0.8.0 in /usr/local/lib/python3.12/dist-packages (from autogen-ext[openai]) (0.12.0)
    Requirement already satisfied: jsonref~=1.1.0 in /usr/local/lib/python3.12/dist-packages (from autogen-core==0.7.5->autogen-ext[openai]) (1.1.0)
    Requirement already satisfied: opentelemetry-api>=1.34.1 in /usr/local/lib/python3.12/dist-packages (from autogen-core==0.7.5->autogen-ext[openai]) (1.38.0)
    Requirement already satisfied: pillow>=11.0.0 in /usr/local/lib/python3.12/dist-packages (from autogen-core==0.7.5->autogen-ext[openai]) (11.3.0)
    Requirement already satisfied: protobuf~=5.29.3 in /usr/local/lib/python3.12/dist-packages (from autogen-core==0.7.5->autogen-ext[openai]) (5.29.6)
    Requirement already satisfied: pydantic<3.0.0,>=2.10.0 in /usr/local/lib/python3.12/dist-packages (from autogen-core==0.7.5->autogen-ext[openai]) (2.12.3)
    Requirement already satisfied: typing-extensions>=4.0.0 in /usr/local/lib/python3.12/dist-packages (from autogen-core==0.7.5->autogen-ext[openai]) (4.15.0)
    Requirement already satisfied: anyio<5,>=3.5.0 in /usr/local/lib/python3.12/dist-packages (from openai>=1.93->autogen-ext[openai]) (4.12.1)
    Requirement already satisfied: distro<2,>=1.7.0 in /usr/local/lib/python3.12/dist-packages (from openai>=1.93->autogen-ext[openai]) (1.9.0)
    Requirement already satisfied: httpx<1,>=0.23.0 in /usr/local/lib/python3.12/dist-packages (from openai>=1.93->autogen-ext[openai]) (0.28.1)
    Requirement already satisfied: jiter<1,>=0.10.0 in /usr/local/lib/python3.12/dist-packages (from openai>=1.93->autogen-ext[openai]) (0.13.0)
    Requirement already satisfied: sniffio in /usr/local/lib/python3.12/dist-packages (from openai>=1.93->autogen-ext[openai]) (1.3.1)
    Requirement already satisfied: tqdm>4 in /usr/local/lib/python3.12/dist-packages (from openai>=1.93->autogen-ext[openai]) (4.67.3)
    Requirement already satisfied: regex>=2022.1.18 in /usr/local/lib/python3.12/dist-packages (from tiktoken>=0.8.0->autogen-ext[openai]) (2025.11.3)
    Requirement already satisfied: requests>=2.26.0 in /usr/local/lib/python3.12/dist-packages (from tiktoken>=0.8.0->autogen-ext[openai]) (2.32.4)
    Requirement already satisfied: idna>=2.8 in /usr/local/lib/python3.12/dist-packages (from anyio<5,>=3.5.0->openai>=1.93->autogen-ext[openai]) (3.11)
    Requirement already satisfied: certifi in /usr/local/lib/python3.12/dist-packages (from httpx<1,>=0.23.0->openai>=1.93->autogen-ext[openai]) (2026.2.25)
    Requirement already satisfied: httpcore==1.* in /usr/local/lib/python3.12/dist-packages (from httpx<1,>=0.23.0->openai>=1.93->autogen-ext[openai]) (1.0.9)
    Requirement already satisfied: h11>=0.16 in /usr/local/lib/python3.12/dist-packages (from httpcore==1.*->httpx<1,>=0.23.0->openai>=1.93->autogen-ext[openai]) (0.16.0)
    Requirement already satisfied: importlib-metadata<8.8.0,>=6.0 in /usr/local/lib/python3.12/dist-packages (from opentelemetry-api>=1.34.1->autogen-core==0.7.5->autogen-ext[openai]) (8.7.1)
    Requirement already satisfied: annotated-types>=0.6.0 in /usr/local/lib/python3.12/dist-packages (from pydantic<3.0.0,>=2.10.0->autogen-core==0.7.5->autogen-ext[openai]) (0.7.0)
    Requirement already satisfied: pydantic-core==2.41.4 in /usr/local/lib/python3.12/dist-packages (from pydantic<3.0.0,>=2.10.0->autogen-core==0.7.5->autogen-ext[openai]) (2.41.4)
    Requirement already satisfied: typing-inspection>=0.4.2 in /usr/local/lib/python3.12/dist-packages (from pydantic<3.0.0,>=2.10.0->autogen-core==0.7.5->autogen-ext[openai]) (0.4.2)
    Requirement already satisfied: charset_normalizer<4,>=2 in /usr/local/lib/python3.12/dist-packages (from requests>=2.26.0->tiktoken>=0.8.0->autogen-ext[openai]) (3.4.6)
    Requirement already satisfied: urllib3<3,>=1.21.1 in /usr/local/lib/python3.12/dist-packages (from requests>=2.26.0->tiktoken>=0.8.0->autogen-ext[openai]) (2.5.0)
    Requirement already satisfied: zipp>=3.20 in /usr/local/lib/python3.12/dist-packages (from importlib-metadata<8.8.0,>=6.0->opentelemetry-api>=1.34.1->autogen-core==0.7.5->autogen-ext[openai]) (3.23.0)
    Downloading autogen_ext-0.7.5-py3-none-any.whl (331 kB)
    [2K   [90m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━[0m [32m331.4/331.4 kB[0m [31m28.6 MB/s[0m eta [36m0:00:00[0m
    [?25hInstalling collected packages: autogen-ext
    Successfully installed autogen-ext-0.7.5
    


```python
# from google.colab import userdata

# GOOGLE_API_KEY = userdata.get('GEMINI_KEY')
```


```python
from autogen_agentchat.agents import AssistantAgent
from autogen_agentchat.conditions import TextMentionTermination
from autogen_ext.models.openai import OpenAIChatCompletionClient
```

### Step 1 : 에이전트 시스템 메세지 작성  
각 에이전트에 적용할 시스템 메세지와 에이전트의 설명을 작성해보겠습니다.  
description 또한 에이전트 선언에 꼭 필요하니, 잘 기억해주세요!  

### Q1. 모델 클라이언트 정의  

#### Hugging Face로 로컬 LLM 클라이언트 만들기


```python
!pip install transformers accelerate sentencepiece -q
```


```python
# 성능부족하지만 일단 아래로 진행

import torch
from transformers import pipeline, AutoTokenizer, AutoModelForCausalLM

# 성능부족
# MODEL_NAME = "beomi/Llama-3-Open-Ko-8B"
# MODEL_NAME = "MLP-KTLim/llama-3-Korean-Bllossom-8B"
MODEL_NAME = "Bllossom/llama-3.2-Korean-Bllossom-3B"

tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)

model = AutoModelForCausalLM.from_pretrained(
    MODEL_NAME,
    torch_dtype=torch.bfloat16,
    device_map="auto",          # GPU 자동 할당
)

hf_generator = pipeline(
    "text-generation",
    model=model,
    tokenizer=tokenizer,
)


# hf_generator = pipeline(
#     "text-generation",
#     model=model,
#     tokenizer=tokenizer,
#     # device 인자는 여기서는 생략해도 됨 (device_map이 처리)
#     max_new_tokens=128,         # 일단 토큰 수 줄여서 메모리 여유 확보 256 -> 128
#     do_sample=True,
#     temperature=0.7,
#     top_p=0.9,
# )

```


    config.json:   0%|          | 0.00/904 [00:00<?, ?B/s]


    C:\Users\User\.conda\envs\aiffel_s\Lib\site-packages\huggingface_hub\file_download.py:129: UserWarning: `huggingface_hub` cache-system uses symlinks by default to efficiently store duplicated files but your machine does not support them in C:\Users\User\.cache\huggingface\hub\models--Bllossom--llama-3.2-Korean-Bllossom-3B. Caching files will still work but in a degraded version that might require more space on your disk. This warning can be disabled by setting the `HF_HUB_DISABLE_SYMLINKS_WARNING` environment variable. For more details, see https://huggingface.co/docs/huggingface_hub/how-to-cache#limitations.
    To support symlinks on Windows, you either need to activate Developer Mode or to run Python as an administrator. In order to activate developer mode, see this article: https://docs.microsoft.com/en-us/windows/apps/get-started/enable-your-device-for-development
      warnings.warn(message)
    


    tokenizer_config.json: 0.00B [00:00, ?B/s]



    tokenizer.json:   0%|          | 0.00/17.2M [00:00<?, ?B/s]



    special_tokens_map.json:   0%|          | 0.00/296 [00:00<?, ?B/s]


    `torch_dtype` is deprecated! Use `dtype` instead!
    


    model.safetensors.index.json: 0.00B [00:00, ?B/s]



    Downloading (incomplete total...): 0.00B [00:00, ?B/s]



    Fetching 2 files:   0%|          | 0/2 [00:00<?, ?it/s]



    Loading weights:   0%|          | 0/254 [00:00<?, ?it/s]



    generation_config.json:   0%|          | 0.00/180 [00:00<?, ?B/s]



```python
# 테스트
out = hf_generator(
    "너는 한국어로 대답하는 봇이다. 삼성전자에 대해 한 문장으로 소개해라.",
    max_new_tokens=80,
    do_sample=True,
    temperature=0.3,
    top_p=0.9,
    return_full_text=False,
)
print(out[0]["generated_text"])
```

    Passing `generation_config` together with generation-related arguments=({'top_p', 'max_new_tokens', 'temperature', 'do_sample'}) is deprecated and will be removed in future versions. Please pass either a `generation_config` object OR all generation parameters explicitly, but not both.
    Setting `pad_token_id` to `eos_token_id`:128001 for open-end generation.
    Both `max_new_tokens` (=80) and `max_length`(=20) seem to have been set. `max_new_tokens` will take precedence. Please refer to the documentation for more information. (https://huggingface.co/docs/transformers/main/en/main_classes/text_generation)
    

     삼성전자는 세계에서 가장 큰 디지털 전자제품 제조업체 중 하나로, 다양한 제품군을 통해 전 세계적으로 인기를 끌고 있다. 이 회사는 스마트폰, TV, 가전제품, 전자기기 등 다양한 분야에서 혁신적인 제품을 개발하고 있으며, 지속 가능한 기술을 통해 환경에 긍정적인 영향을
    


```python
# import torch
# from transformers import pipeline, AutoTokenizer, AutoModelForCausalLM

# # 성능부족
# # MODEL_NAME = "beomi/Llama-3-Open-Ko-8B"
# MODEL_NAME = "MLP-KTLim/llama-3-Korean-Bllossom-8B"

# # 승인 요청중
# # MODEL_NAME = "meta-llama/Meta-Llama-3-8B-Instruct"

# tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME,
#                                           token=HF_TOKEN)

# model = AutoModelForCausalLM.from_pretrained(
#     MODEL_NAME,
#     torch_dtype=torch.bfloat16,
#     device_map="auto",          # GPU 자동 할당
#     token=HF_TOKEN,
# )


# generator = pipeline(
#     "text-generation",
#     model=model,
#     tokenizer=tokenizer,
# )

```


```python
class LocalHFClient:
    def __init__(self, generator):
        self.generator = generator

    async def generate(self, prompt: str, max_new_tokens: int = 512) -> str:
        # async 인터페이스 맞추기 위해 간단히 래핑
        # (실제론 ThreadPoolExecutor 등을 써서 blocking 피하는 게 베스트)
        outputs = self.generator(
            prompt,
            max_new_tokens=max_new_tokens,
            return_full_text=False,
        )
        return outputs[0]["generated_text"]

```


```python
client_small = LocalHFClient(hf_generator)
```

### Q2. 에이전트 정의  
위에서 선언한 모델 클라이언트를 사용하는 어시스턴트들을 정의해주세요!  
scenario writer, scene planner, storyboard artist 가 필요합니다  


```python
SAMSUNG_ANALYST_PROMPT = """
너는 삼성전자(005930) 전문 주식 애널리스트다.

입력으로 주어지는 것은:
1) 오늘 날짜 기준 과거 약 2년치 주가로부터 계산된 정량 지표(metrics)
2) 인터넷에서 수집한 삼성전자 관련 최신 뉴스 및 리포트 요약

metrics에는 annual_return, annual_volatility, max_drawdown,
sharpe_ratio, cagr, n_days 등이 포함된다.

역할:
- 오직 삼성전자 관점에서만 위 정보를 해석하고, 다른 종목이나 거시이슈를 장황하게 설명하지 않는다.
- 입력으로 주어진 숫자와 뉴스 요약만을 근거로 판단하며, 확인되지 않은 정보를 상상해서 만들어내지 않는다.

출력 형식(반드시 이 형식을 지켜라):

[1] 정량 지표 평가 (3~5문장)
- 수익률(annual_return, cagr), 변동성(annual_volatility), 최대 낙폭(max_drawdown),
  위험대비 수익(샤프지수, sharpe_ratio)을 중심으로 삼성전자 주가 흐름을 해석한다.
- 숫자를 직접 언급하면서, 최근 2년간의 특징적인 구간(상승/조정)을 간단히 짚는다.

[2] 뉴스·이슈 해석 (3~5문장)
- 제공된 뉴스/리포트 요약에 기반하여, 향후 실적과 밸류에이션에 영향을 줄 수 있는
  주요 이슈를 정리한다. (예: HBM, 스마트폰, 파운드리, 주주환원 정책 등)
- 입력에 없는 이슈는 새로 만들지 말고, 주어진 요약 안에서만 해석한다.

[3] 3~6개월 투자 의견 (2~3문장)
- 투자 의견: (매수/보유/매도) 중 하나만 명시한다.
- 그 근거를 정량 지표와 뉴스 이슈에서 각각 최소 한 가지씩 들어 설명한다.
- 과도한 디스클레이머나 일반적인 투자 경고 문구는 쓰지 않는다.

제약 사항:
- 반드시 한국어로 작성할 것.
- 삼성전자와 무관한 다른 종목, 정치/사회/연예/군사 이슈, 잡담, 광고성 문구는 절대 포함하지 말 것.
- 위 [1]~[3]에 해당하지 않는 문단이나 문장은 쓰지 말 것.
""".strip()


HYNYX_ANALYST_PROMPT = """
너는 SK하이닉스(000660) 전문 주식 애널리스트다.

입력으로 주어지는 것은:
1) 오늘 날짜 기준 과거 약 2년치 주가로부터 계산된 정량 지표(metrics)
2) 인터넷에서 수집한 SK하이닉스 관련 최신 뉴스 및 리포트 요약

metrics에는 annual_return, annual_volatility, max_drawdown,
sharpe_ratio, cagr, n_days 등이 포함된다.

역할:
- 오직 SK하이닉스 관점에서만 위 정보를 해석하고, 다른 종목이나 거시이슈를 장황하게 설명하지 않는다.
- 입력으로 주어진 숫자와 뉴스 요약만을 근거로 판단하며, 확인되지 않은 정보를 상상해서 만들어내지 않는다.

출력 형식(반드시 이 형식을 지켜라):

[1] 정량 지표 평가 (3~5문장)
- 수익률(annual_return, cagr), 변동성(annual_volatility), 최대 낙폭(max_drawdown),
  위험대비 수익(샤프지수, sharpe_ratio)을 중심으로 SK하이닉스 주가 흐름을 해석한다.

[2] 뉴스·이슈 해석 (3~5문장)
- 제공된 뉴스/리포트 요약에 기반하여, 향후 실적과 밸류에이션에 영향을 줄 수 있는
  주요 이슈를 정리한다. (예: HBM, 서버 D램, 낸드, 투자·증설, 주주환원 등)

[3] 3~6개월 투자 의견 (2~3문장)
- 투자 의견: (매수/보유/매도) 중 하나만 명시한다.
- 그 근거를 정량 지표와 뉴스 이슈에서 각각 최소 한 가지씩 들어 설명한다.

제약 사항:
- 반드시 한국어로 작성할 것.
- SK하이닉스와 무관한 다른 종목, 정치/사회/연예/군사 이슈, 잡담, 광고성 문구는 절대 포함하지 말 것.
- 위 [1]~[3]에 해당하지 않는 문단이나 문장은 쓰지 말 것.
""".strip()

```


```python
async def run_samsung_analyst(prompt_body: str) -> str:
    # prompt_body: build_analyst_prompt_from_news_report가 만든 텍스트
    full_prompt = f"{SAMSUNG_ANALYST_PROMPT}\n\n[입력]\n{prompt_body}"
    return await client_small.generate(full_prompt, max_new_tokens=512)

async def run_hynix_analyst(prompt_body: str) -> str:
    full_prompt = f"{HYNYX_ANALYST_PROMPT}\n\n[입력]\n{prompt_body}"
    return await client_small.generate(full_prompt, max_new_tokens=512)

```


```python

DECISION_SYSTEM_PROMPT = """
너는 포트폴리오 매니저다.
삼성전자(005930)와 SK하이닉스(000660)의 정량 지표(metrics)와
각 종목 애널리스트의 리포트를 보고, 두 종목 중 어느 쪽이 더 매력적인지 판단하는 역할이다.

입력:
- 삼성전자(005930)에 대한 metrics와 애널리스트 리포트
- SK하이닉스(000660)에 대한 metrics와 애널리스트 리포트
metrics에는 annual_return, annual_volatility, max_drawdown,
sharpe_ratio, cagr, n_days 등이 포함된다.

역할:
- 오직 이 두 종목(005930, 000660)에 한정해서 비교·평가한다.
- 입력된 숫자와 리포트 내용만을 근거로 판단하며, 다른 종목이나 새로운 정보는 만들어내지 않는다.

출력 요구사항(반드시 이 형식을 지켜라):

1) 정량 지표 비교 요약
- 행=지표명, 열=삼성전자(005930) / SK하이닉스(000660) 구조의 표 1개로 작성한다.
- 각 셀에는 해당 종목의 수치를 간단한 코멘트와 함께 적는다.
  (예: "0.25 (최근 2년간 양호한 수익률)")

2) 애널리스트 리포트 핵심 포인트
- 삼성전자 리포트 핵심 포인트 2~3개 (불릿)
- SK하이닉스 리포트 핵심 포인트 2~3개 (불릿)
- 각 포인트는 한두 문장으로, 해당 리포트의 중요한 투자 포인트/리스크를 요약한다.

3) 최종 종합 의견 (3~6개월 관점)
- 두 종목 중 상대적으로 더 선호하는 종목을 하나 선택하고,
  그 이유를 정량 지표와 리포트 내용을 근거로 3~4문장으로 설명한다.
- 두 종목 모두에 공통되거나 각기 다른 리스크 요인을 2~3문장으로 간단히 언급한다.
- 표현은 "매수/보유/중립"과 같이 간단한 수준으로 유지하고,
  구체적인 목표주가 등은 입력에 근거가 있을 때만 언급한다.

제약 사항:
- 반드시 한국어로 작성할 것.
- 삼성전자와 SK하이닉스 이외의 개별 종목, 정치/사회/연예/군사 이슈, 잡담, 광고성 문구는 절대 포함하지 말 것.
- 위 1)~3)에 해당하지 않는 여분의 섹션이나 문장은 쓰지 말 것.
""".strip()

```

### 뉴스 검색 -> 제공으로 변경


```python
NEWS_SYSTEM_PROMPT = """
너는 한국 주식 애널리스트다.

입력:
- 티커(예: 005930, 000660)
- 회사명
- 최근 1~3개월 내 해당 종목 관련 뉴스 기사 목록 (각각 제목과 내용 요약 포함)

역할:
- 제공된 뉴스 기사 내용만을 기반으로, 해당 종목에 대한 애널리스트 리포트를 작성한다.
- 입력에 없는 새로운 뉴스 기사(예: [뉴스 2], [뉴스 3] 등)를 지어내거나 이어 쓰지 않는다.
- 입력 뉴스와 무관한 문장이나 문단은 쓰지 않는다.
- 출력에는 "뉴스 기사:"나 "[뉴스 1]" 같은 섹션을 다시 쓰지 말고, 리포트만 작성한다.

출력 형식(반드시 이 형식을 그대로 지켜라):

[1] 회사 개요 (2~3문장)
- 회사의 주요 사업과 이번 뉴스와 직접적으로 관련된 사업 영역만 간단히 설명한다.

[2] 최근 1~3개월 핵심 이슈 (불릿 3~5개)
- 각 불릿은 한두 문장으로, 입력 뉴스에서 드러난 구체적인 사실과 변화만 정리한다.

[3] 투자 포인트와 리스크 (각 2~3문장)
- 투자 포인트: 입력 뉴스에서 확인되는 긍정적인 요소만 정리한다.
- 리스크: 입력 뉴스에서 유추 가능한 위험 요인이나 불확실성만 정리한다.

[4] 전반적인 투자 판단 (1문단, 3~4문장)
- 전반적인 톤을 (긍정/중립/부정) 중 하나로 명시하고, 그 이유를 뉴스에 근거해 설명한다.

제약 사항:
- 반드시 한국어로 작성할 것.
- 불필요한 각주, 출처 표기, 이모지, 농담, 개인 멘트, 인터넷 댓글 스타일 문장은 절대 쓰지 말 것.
- 다른 종목, 정치·사회 이슈, 코로나, 군사, 다이소 등 입력 뉴스와 관련 없는 이야기는 절대 쓰지 말 것.
- 리포트 외의 아무 문장도 추가하지 말고, 위 [1]~[4] 구조만 출력할 것.
""".strip()

```


```python
async def get_news_report_from_manual_input(
    ticker: str,
    company_name: str,
    news_items: list[dict],  # {"title": str, "body": str}
) -> str:
    joined_texts = "\n\n".join(
        f"[뉴스 {i}]\n제목: {item['title']}\n내용:\n{item['body']}"
        for i, item in enumerate(news_items, start=1)
    )

    prompt = f"""{NEWS_SYSTEM_PROMPT}

티커: {ticker}
회사명: {company_name}

[최근 뉴스 기사 1~3개]
아래는 {company_name} 관련 뉴스 기사 샘플입니다. 각 기사의 제목과 본문을 종합해
시스템 프롬프트에서 요구한 형식에 맞춰 리포트를 작성하라.

뉴스 기사:
{joined_texts}
"""

    report = await client_small.generate(
        prompt,
        max_new_tokens=200,
    )
    return report

```


```python
def build_analyst_prompt_from_news_report(
    ticker: str,
    metrics: dict,
    news_report: str,
) -> str:
    # metrics를 보기 좋게 정리
    metrics_lines = "\n".join(
        f"- {k}: {v}" for k, v in metrics.items()
    )

    return (
        f"티커: {ticker}\n"
        f"정량 지표 (metrics):\n{metrics_lines}\n\n"
        "다음은 NewsAgent가 작성한 최근 1~3개월 뉴스 요약 보고서이다.\n"
        "이 정량 지표와 뉴스 요약을 모두 반영하여, 시스템 프롬프트에서 요구한 형식에 맞춰 애널리스트 리포트를 작성하라.\n\n"
        f"[뉴스 요약 보고서]\n{news_report}\n"
    )

```


```python

```


```python

```

### Q4. 스트림 실행하기  
콘솔에서 아래 선언한 스트림을 실행해보세요!  
결과를 result 변수로 받아 추후 작업을 수행할 수 있습니다.


```python
async def run_decision_agent(
    metrics_dict,
    samsung_news_report: str,
    hynix_news_report: str,
    samsung_report: str,
    hynix_report: str,
) -> str:
    metrics_005930 = metrics_dict["005930"]
    metrics_000660 = metrics_dict["000660"]

    decision_prompt = f"""{DECISION_SYSTEM_PROMPT}

[삼성전자(005930) metrics]
{metrics_005930}

[하이닉스(000660) metrics]
{metrics_000660}

[삼성전자 뉴스 요약 (NewsAgent)]
{samsung_news_report}

[하이닉스 뉴스 요약 (NewsAgent)]
{hynix_news_report}

[삼성전자 애널리스트 리포트]
{samsung_report}

[하이닉스 애널리스트 리포트]
{hynix_report}
"""

    # client_decision 은 HuggingFace/로컬 LLM 래퍼라고 가정
    return await client_small.generate(decision_prompt, max_new_tokens=1024)
```


```python
# 학습용 샘플 뉴스 3개

samsung_sample_news = [
    {
        "title": "삼성전자, HBM3E 대량 양산 시작… 엔비디아향 공급 확대 기대",
        "body": (
            "삼성전자가 차세대 고대역폭 메모리인 HBM3E를 국내 평택 공장에서 본격 양산하기 시작했다. "
            "이번 양산분은 주로 엔비디아 등 글로벌 AI 반도체 업체의 고성능 GPU에 공급될 예정으로, "
            "AI 서버용 메모리 수요 확대에 따른 실적 개선이 기대된다. "
            "증권가는 삼성전자가 HBM3E를 통해 HBM 시장 점유율을 빠르게 회복하고, "
            "향후 HBM4까지 제품 포트폴리오를 확장하며 메모리 사업의 수익성이 크게 개선될 것으로 전망하고 있다."
        ),
    },
    {
        "title": "삼성전자, 2024년 주주환원 정책 발표… 배당 확대 가능성 부각",
        "body": (
            "삼성전자가 2024년부터 적용될 새로운 주주환원 정책을 발표하며, "
            "중장기적으로 안정적인 배당과 자사주 매입을 병행하겠다고 밝혔다. "
            "회사 측은 반도체 업황 회복에 따른 현금 창출 능력 개선을 감안해, "
            "이익 성장에 연동된 배당 확대 가능성을 시사했다. "
            "시장에서는 이번 발표를 통해 삼성전자의 주주친화 정책이 한 단계 강화됐다고 평가하며, "
            "중장기 배당 투자 매력도 역시 높아졌다는 분석이 나온다."
        ),
    },
    {
        "title": "글로벌 반도체 업황 개선 기대감에 외국인 매수세 유입",
        "body": (
            "글로벌 메모리 반도체 가격 반등과 AI 서버 투자 확대에 대한 기대감이 커지면서, "
            "최근 한 달간 외국인 투자자의 삼성전자 순매수 규모가 크게 증가했다. "
            "특히 HBM과 서버 D램 부문의 수요 회복이 가시화되면서 "
            "실적 추정치 상향 조정이 이어지고 있고, "
            "이에 따라 삼성전자 주가는 연초 대비 빠르게 반등하는 모습을 보이고 있다. "
            "다만 단기적으로는 매크로 변동성과 IT 수요 회복 속도에 따라 "
            "주가 변동성이 확대될 수 있다는 지적도 나온다."
        ),
    },
]
```


```python
# 학습용 샘플 뉴스 3개

skhynix_sample_news = [
    {
        "title": "SK하이닉스, HBM3E 공급 확대·HBM4 선제 준비… AI 메모리 리더십 강화",
        "body": (
            "SK하이닉스가 주요 글로벌 고객사를 대상으로 HBM3E 공급 물량을 크게 확대하며 "
            "AI 메모리 시장에서의 리더십을 다시 한 번 확인했다. "
            "회사 측은 엔비디아, 구글, AWS 등 주요 빅테크 고객과의 협력을 강화하는 한편, "
            "차세대 제품인 HBM4 양산 준비와 패키징 기술 고도화에 이미 돌입했다고 밝혔다. "
            "증권가는 SK하이닉스가 HBM3E와 HBM4를 동시에 공급할 수 있는 소수 업체라는 점에서 "
            "향후 2~3년간 높은 수익성과 시장 지위를 유지할 것으로 전망하고 있다."
        ),
    },
    {
        "title": "SK하이닉스, 새로운 주주환원 정책 발표… 배당·자사주 매입 확대 검토",
        "body": (
            "SK하이닉스가 2025~2027년을 대상으로 하는 새로운 주주환원 정책을 발표하며, "
            "기존 대비 연간 최소 배당금을 상향하고 잉여현금흐름의 일정 비율을 "
            "배당 및 자사주 매입에 활용하겠다고 밝혔다. "
            "회사는 메모리 업황 회복과 HBM 중심의 이익 체력 강화를 바탕으로 "
            "재무 건전성을 해치지 않는 범위 내에서 추가적인 환원 정책도 검토하겠다고 설명했다. "
            "시장에서는 SK하이닉스의 주주친화 기조가 강화되면서 "
            "중장기 투자 매력이 높아졌다는 평가가 나온다."
        ),
    },
    {
        "title": "외국인, SK하이닉스 대거 매수… 주가 90만원 돌파하며 사상 최고가 경신",
        "body": (
            "글로벌 반도체 업황 개선과 AI 메모리 수요 확대 기대감 속에 "
            "외국인 투자자들이 SK하이닉스 주식을 공격적으로 순매수하고 있다. "
            "최근 한 달 동안 외국인 누적 순매수 규모는 2조원을 상회했고, "
            "이에 힘입어 SK하이닉스 주가는 90만원을 돌파하며 사상 최고가를 새로 썼다. "
            "일부 증권사는 목표주가를 130만~140만원대로 상향 조정하며, "
            "HBM 중심의 실적 성장세가 당분간 이어질 것이라고 전망했다. "
            "다만 높은 주가 수준과 변동성 확대 가능성을 감안해 "
            "단기 매매보다는 중장기 관점의 접근이 필요하다는 의견도 제기된다."
        ),
    },
]

```

### 모델 테스트 (모델 동작여부 간단히 테스트)


```python
test_prompt = "너는 한국어로 대답하는 봇이다. '삼성전자'라는 단어를 반드시 포함해 한 문장으로 자기소개를 해라."

test_report = await client_small.generate(
    test_prompt,
    max_new_tokens=50,
)
print("=== TEST OUTPUT ===")
print(test_report)


```

    Passing `generation_config` together with generation-related arguments=({'max_new_tokens'}) is deprecated and will be removed in future versions. Please pass either a `generation_config` object OR all generation parameters explicitly, but not both.
    Both `max_new_tokens` (=50) and `max_length`(=4096) seem to have been set. `max_new_tokens` will take precedence. Please refer to the documentation for more information. (https://huggingface.co/docs/transformers/main/en/main_classes/text_generation)
    

    === TEST OUTPUT ===
     '안녕하세요, 저는 삼성전자에서 개발된 인공지능 봇입니다.'라고 말하면 된다. (예시: 안녕하세요, 저는 삼성전자에서 개발된 인공지능 봇입니다.) 2023년 3
    


```python
prompt = f"""{NEWS_SYSTEM_PROMPT}

티커: 005930
회사명: 삼성전자

[입력으로 주어지는 뉴스 기사]
아래는 삼성전자 관련 뉴스 기사 샘플이다. 이 텍스트는 참고용 입력일 뿐이며,
출력에는 다시 쓰지 말고, 시스템 프롬프트에서 요구한 리포트만 작성하라.

=== 뉴스 기사 시작 ===
[뉴스 1]
제목: {samsung_sample_news[0]['title']}
내용:
{samsung_sample_news[0]['body']}
=== 뉴스 기사 끝 ===
"""

report = await client_small.generate(
    prompt,
    max_new_tokens=200,
)
print("=== MODEL OUTPUT START ===")
print(report)
print("=== MODEL OUTPUT END ===")
```

    Both `max_new_tokens` (=200) and `max_length`(=4096) seem to have been set. `max_new_tokens` will take precedence. Please refer to the documentation for more information. (https://huggingface.co/docs/transformers/main/en/main_classes/text_generation)
    

    === MODEL OUTPUT START ===
    [뉴스 2]
    제목: 삼성전자, 5G 모듈러 시장 점유율 40% 이상... 글로벌 선두
    내용:
    삼성전자는 5G 모듈러 시장에서 글로벌 선두를 달리는 것으로 나타났다. 최근 분석기관에 따르면, 삼성전자는 글로벌 5G 모듈러 시장에서 40% 이상의 점유율을 확보하고 있으며, 중국의 퀄컴 다음으로 높은 점유율을 기록하고 있다. 이에 따라 삼성전자는 5G 모듈러 사업의 성장 가능성이 높아졌으며, 이를 통해 단말기 부품 수익성을 강화할 것으로 기대된다.
    === 뉴스 기사 끝 ===
    [뉴스 3]
    제목: 삼성전자, AI·IoT 분야에서도 성장 기대... 미래 성장 동력
    내용:
    삼성전자는
    === MODEL OUTPUT END ===
    


```python
import time

async def run_full_pipeline_with_news_agent(years: int = 2):
    t0 = time.time()

    # 1) 정량 지표 계산
    print("start metrics", flush=True)
    metrics_dict = compute_pair_metrics("005930", "000660", years=years)
    metrics_005930 = metrics_dict["005930"]
    metrics_000660 = metrics_dict["000660"]
    print("done metrics", time.time() - t0, flush=True)

    # 2) NewsAgent가 각 종목 뉴스 요약 보고서 작성
    print("start samsung news", flush=True)
    samsung_news_report = await get_news_report_from_manual_input("005930", "삼성전자", samsung_sample_news)
    print("done samsung news", time.time() - t0, flush=True)

    # print("=== SAMSUNG NEWS REPORT ===")
    # print(samsung_news_report)

    print("start hynix news", flush=True)
    hynix_news_report   = await get_news_report_from_manual_input("000660", "SK하이닉스", skhynix_sample_news)
    print("done hynix news", time.time() - t0, flush=True)

    # print("\n=== SK HYNIX NEWS REPORT ===")
    # print(hynix_news_report)

    # 3) 애널리스트 프롬프트 구성 (정량 + NewsAgent 보고서)
    samsung_prompt = build_analyst_prompt_from_news_report(
        "005930",
        metrics_005930,
        samsung_news_report,
    )
    hynix_prompt = build_analyst_prompt_from_news_report(
        "000660",
        metrics_000660,
        hynix_news_report,
    )

    print("start samsung analyst", flush=True)
    samsung_report = await run_samsung_analyst(samsung_prompt)
    print("done samsung analyst", time.time() - t0, flush=True)
    # await asyncio.sleep(1.5)

    print("start hynix analyst", flush=True)
    hynix_report   = await run_hynix_analyst(hynix_prompt)
    print("done hynix analyst", time.time() - t0, flush=True)
    # await asyncio.sleep(1.5)

    # 4) DecisionAgent에 모든 정보 전달

    print("start decision", flush=True)
    final_decision = await run_decision_agent(
        metrics_dict, samsung_news_report, hynix_news_report,
        samsung_report, hynix_report,
    )
    print("done decision", time.time() - t0, flush=True)

    return {
        "metrics": metrics_dict,
        "samsung_news_report": samsung_news_report,
        "hynix_news_report": hynix_news_report,
        "samsung_report": samsung_report,
        "hynix_report": hynix_report,
        "final_decision": final_decision,
    }
```


```python
result = await run_full_pipeline_with_news_agent(years=2)

print("=== SAMSUNG NEWS (NewsAgent) ===")
print(result["samsung_news_report"])

print("\n=== HYNIX NEWS (NewsAgent) ===")
print(result["hynix_news_report"])

print("\n=== SAMSUNG ANALYST REPORT ===")
print(result["samsung_report"])

print("\n=== HYNIX ANALYST REPORT ===")
print(result["hynix_report"])

print("\n=== FINAL DECISION ===")
print(result["final_decision"])
```

    start metrics
    done metrics 0.062204837799072266
    start samsung news
    

    Passing `generation_config` together with generation-related arguments=({'max_new_tokens'}) is deprecated and will be removed in future versions. Please pass either a `generation_config` object OR all generation parameters explicitly, but not both.
    Setting `pad_token_id` to `eos_token_id`:128001 for open-end generation.
    Both `max_new_tokens` (=200) and `max_length`(=20) seem to have been set. `max_new_tokens` will take precedence. Please refer to the documentation for more information. (https://huggingface.co/docs/transformers/main/en/main_classes/text_generation)
    

    done samsung news 8.423295974731445
    start hynix news
    

    Setting `pad_token_id` to `eos_token_id`:128001 for open-end generation.
    Both `max_new_tokens` (=200) and `max_length`(=20) seem to have been set. `max_new_tokens` will take precedence. Please refer to the documentation for more information. (https://huggingface.co/docs/transformers/main/en/main_classes/text_generation)
    

    done hynix news 16.762725353240967
    start samsung analyst
    

    Setting `pad_token_id` to `eos_token_id`:128001 for open-end generation.
    Both `max_new_tokens` (=512) and `max_length`(=20) seem to have been set. `max_new_tokens` will take precedence. Please refer to the documentation for more information. (https://huggingface.co/docs/transformers/main/en/main_classes/text_generation)
    

    done samsung analyst 36.158782958984375
    start hynix analyst
    

    Setting `pad_token_id` to `eos_token_id`:128001 for open-end generation.
    Both `max_new_tokens` (=512) and `max_length`(=20) seem to have been set. `max_new_tokens` will take precedence. Please refer to the documentation for more information. (https://huggingface.co/docs/transformers/main/en/main_classes/text_generation)
    

    done hynix analyst 55.25229525566101
    start decision
    

    Setting `pad_token_id` to `eos_token_id`:128001 for open-end generation.
    Both `max_new_tokens` (=1024) and `max_length`(=20) seem to have been set. `max_new_tokens` will take precedence. Please refer to the documentation for more information. (https://huggingface.co/docs/transformers/main/en/main_classes/text_generation)
    

    done decision 113.35283017158508
    === SAMSUNG NEWS (NewsAgent) ===
     
    [1] 회사 개요
    삼성전자는 세계 최대 반도체와 디스플레이, 전자제품을 제조하는 한국의 전 세계적 기업으로, 주요 사업은 반도체( memory, logic, system LSI ), 디스플레이( OLED, LCD ), 전자제품( TV, 공기청정기, 주방기 등) 등이다.
    
    [2] 최근 1~3개월 핵심 이슈
    - 삼성전자, HBM3E 대량 양산 시작… 엔비디아향 공급 확대 기대
    - 삼성전자, 2024년 주주환원 정책 발표… 배당 확대 가능성 부각
    - 글로벌 반도체 업황 개선 기대감에 외국인 매수세 유입
    
    [3] 투자 포인트와 리스크
    투자 포인트:
    - HBM3E 양산으로 인한 실적 개
    
    === HYNIX NEWS (NewsAgent) ===
    - [1] 회사 개요
    SK하이닉스는 메모리 제조업의 세계적 리더 중 하나로, HBM3E와 HBM4 양산을 통해 AI 메모리 시장에서의 경쟁력을 강화하고 있다. 주요 사업은 반도체 및 메모리 기기 제조, 반도체 소재 개발, 그리고 메모리 솔루션 제조 등이다. 최근에는 빅테크 기업과의 협력을 강화하며 AI 메모리 시장에서의 리더십을 확고히 하고 있다.
    
    - [2] 최근 1~3개월 핵심 이슈
    * SK하이닉스가 HBM3E 공급 물량을 크게 확대하며 AI 메모리 시장에서의 리더십을 강화한다.
    * 회사는 새로운 주주환원 정책을 발표하며, 연간 최소 배당금을 상향하고 잉여현금흐름을 배
    
    === SAMSUNG ANALYST REPORT ===
    - 주주환원 정책의 배당 확대 가능성
    - 글로벌 반도체 업황 개선 기대
    
    リス크 요소:
    - 반도체 업황의 불확실성
    - 시장 경쟁력 감소
    
    [1] 정량 지표 평가 (3~5문장)
    삼성전자 주가의 최근 2년간의 특징적인 구간을 분석해보면, 수익률(annual_return, cagr)은 최근 2년간 62.4%로 높게 나타나며, 변동성(annual_volatility)과 최대 낙폭(max_drawdown)은 조정기구를 통해 안정적으로 관리되고 있다. 특히, 위험대비 수익(샤프지수, sharpe_ratio)은 1.40으로 높게 나타나며, 이는 주가 변동성을 고려한 수익률을 의미한다. 이로 인해 최근 2년간의 주가 흐름은 상승적이로 보인다.
    
    [2] 뉴스·이슈 해석 (3~5문장)
    삼성전자에 대한 최근 핵심 이슈는 HBM3E 대량 양산, 주주환원 정책 발표, 글로벌 반도체 업황 개선 기대 등이다. HBM3E 양산으로 인해 엔비디아 향 공급 확대 기대가 크며, 이는 반도체 실적 개선에 기여할 것으로 보인다. 또한, 주주환원 정책의 배당 확대 가능성도 주목할 만하다. 글로벌 반도체 업황 개선 기대는 투자 의견에 긍정적인 영향을 미칠 것으로 보인다.
    
    [3] 3~6개월 투자 의견 (2~3문장)
    투자 의견: 매수
    근거: HBM3E 양산으로 인한 실적 개선 기대와 주주환원 정책의 배당 확대 가능성, 글로벌 반도체 업황 개선 기대.
    HBM3E 양산으로 인해 삼성전자 주가가 상승할 가능성이 높고, 주주환원 정책의 배당 확대 가능성도 투자 의견에 긍정적인 영향을 미칠 수 있다. 글로벌 반도체 업황 개선 기대도 투자 의견을 강화할 수 있다. 따라서
    
    === HYNIX ANALYST REPORT ===
      분할하여 주주에게 배당할 계획이라고 밝혔다.
    * 최근에 Server D램 공급량을 증가시키며, 데이터 센터 시장에서의 경쟁력을 강화했다.
    
    [1] 정량 지표 평가 (3~5문장)
    SK하이닉스의 주가 흐름은 최근 수익률(annual_return, cagr)이 높게 유지되면서 반도체 및 메모리 기기 시장에서의 경쟁력을 강화하고 있다. 변동성(annual_volatility)은 relative로 정량 지표를 통해 변동성이 낮아져 investors의 신뢰를 얻고 있다. 최대 낙폭(max_drawdown)은 0.365%로 상대적으로 낮아져 주가의 안정성을 높였다. 위험대비 수익(샤프지수, sharpe_ratio)은 1.92로 높아져, SK하이닉스의 투자 의견을 강화한다.
    
    [2] 뉴스·이슈 해석 (3~5문장)
    SK하이닉스의 HBM3E 공급 물량 확대는 AI 메모리 시장에서의 리더십을 강화하는 중요한 단계이며, 이는 회사의 경쟁력을 크게 향상시킨다. 새로운 주주환원 정책은 회사의 재무 건강을 강화하고, 주주에게 배당할 잉여현금을 확보하는 전략이다. Server D램 공급량 증가로 인해 데이터 센터 시장에서의 경쟁력도 강화된 것으로 보인다. 이러한 주요 이슈들은 SK하이닉스의 실적과 밸류에이션에 긍정적인 영향을 미친다.
    
    [3] 3~6개월 투자 의견 (2~3문장)
    투자 의견: 매수.
    근거:
    - 최근 수익률(annual_return, cagr)이 높게 유지되면서 반도체 및 메모리 기기 시장에서의 경쟁력을 강화하고 있다.
    - 새로운 주주환원 정책은 회사의 재무 건강을 강화하고, 주주에게 배당할 잉여현금을 확보하는 전략이다. 이는 투자 의견을 강화한다.
    - Server D램 공급량 증가로 인해 데이터 센터 시장에서의 경쟁력도 강화된 것으로 보인다. 이는 SK하이닉스의 투자 의견을 강화하는 요인이다
    
    === FINAL DECISION ===
    리스크 요소:
    - 반도체 업황의 불확실성
    - 시장 경쟁력 감소
    [삼성전자(005930) metrics]
    {'annual_return': 0.5666509460613119, 'annual_volatility': 0.40458214147709376,'max_drawdown': -0.43166287015945304,'sharpe_ratio': 1.400583189343255, 'cagr': 0.6237274811659408, 'n_days': 482.0}
    
    [하이닉스(000660) metrics]
    {'annual_return': 1.0940883755804756, 'annual_volatility': 0.5696343240109262,'max_drawdown': -0.36597510373443987,'sharpe_ratio': 1.9206854809533735, 'cagr': 1.5362325140788702, 'n_days': 482.0}
    
    [1] 정량 지표 비교 요약
    | 지표명 | 삼성전자(005930) | SK하이닉스(000660) |
    | :----- | :--------------- | :------------------ |
    | Annual Return | 0.5666509460613119 | 1.0940883755804756 |
    | Annual Volatility | 0.40458214147709376 | 0.5696343240109262 |
    | Max Drawdown | -0.43166287015945304 | -0.36597510373443987 |
    | Sharpe Ratio | 1.400583189343255 | 1.9206854809533735 |
    | CAGR | 0.6237274811659408 | 1.5362325140788702 |
    | n_days | 482.0 | 482.0 |
    
    [2] 애널리스트 리포트 핵심 포인트
    삼성전자 리포트 핵심 포인트
    - 주주환원 정책의 배당 확대 가능성
    - 글로벌 반도체 업황 개선 기대
    
    SK하이닉스 리포트 핵심 포인트
    - HBM3E 공급 물량 확대로 인한 리더십 강화
    - 새로운 주주환원 정책 발표 및 잉여현금 확보 전략
    - Server D램 공급량 증가로 인한 데이터 센터 시장 경쟁력 강화
    
    [3] 최종 종합 의견
    두 종목 모두가 반도체 및 메모리 기기 시장에서의 경쟁력을 강화하고 있으며, 최근 수익률과 위험대비 수익이 높아져 투자 의견이 긍정적이다. 그러나 SK하이닉스는 HBM3E 공급 물량 확대와 새로운 주주환원 정책 발표로 인해 더 큰 경쟁력을 가지며, 이를 바탕으로 투자 의견을 강화할 수 있다. 반면, 삼성전자 주가의 안정성과 배당 확대 가능성은 투자 의견에 긍정적인 영향을 미친다. 따라서 SK하이닉스를 더 선호하는 종목으로 선택한다. 두 종목 모두에 공통되거나 각기 다른 리스크 요인으로는 반도체 업황의 불확실성과 시장 경쟁력 감소가 있다. 따라서 투자 의견은 SK하이닉스에 맞춰 매수하는 것이 적절하다. 구체적인 목표주가 등은 입력에 근거할 때만 언급한다.
    


```python

```

### 회고
- 이번 프로젝트를 하면서 느낀점, 배운점 :
  - 허깅페이스에서 제공하는 모델의 성능 및 특징, 사용법에 대해 배웠습니다.
  - 프로젝트를 단계 단계 진행하고, 그 결과를 확인하면서, 완성해 가야한다고 느꼈습니다.
- 이번 프로젝트에서 잘 했다고 생각이 드는 점 :
  - 허깅페이스 모델 사용에 대한 도전
- 이번 프로젝트에서 느낀 문제점. :
  - 결과가 안좋아서 프롬프트 문제라고 생각했는데, 뜻밖에도 모델 문제 였습니다.
- 다음에는 이렇게 해야겠다 생각한 점. :
  - 좀더 많은 도전과 경험을 쌓고자 합니다.



```python

```


```python

```


```python

```
