-- ============================================================
-- PROJETO: Análise Estatística de Dados Transacionais
-- ETAPA 01: Estatística Descritiva
-- ============================================================


-- ------------------------------------------------------------
-- 1. ENTENDIMENTO DA BASE
-- ------------------------------------------------------------

SELECT COUNT(*) AS quantidade_transacoes
FROM transacoes;


SELECT
    MIN(data_transacao) AS primeira_data,
    MAX(data_transacao) AS ultima_data
FROM transacoes;


-- ------------------------------------------------------------
-- 2. MÉDIA E MEDIANA
-- ------------------------------------------------------------

SELECT
    ROUND(AVG(valor_bruto), 2) AS media_valor
FROM transacoes;


SELECT
    ROUND(
        PERCENTILE_CONT(0.50)
        WITHIN GROUP (ORDER BY valor_bruto)::numeric,
        2
    ) AS mediana_valor
FROM transacoes;


-- ------------------------------------------------------------
-- 3. MODA CATEGÓRICA
-- ------------------------------------------------------------

SELECT
    meio_pagamento_id,
    COUNT(*) AS quantidade
FROM transacoes
GROUP BY meio_pagamento_id
ORDER BY quantidade DESC;


-- ------------------------------------------------------------
-- 4. QUARTIS E PERCENTIS
-- ------------------------------------------------------------

SELECT
    ROUND(PERCENTILE_CONT(0.25)
        WITHIN GROUP (ORDER BY valor_bruto)::numeric, 2) AS q1,

    ROUND(PERCENTILE_CONT(0.50)
        WITHIN GROUP (ORDER BY valor_bruto)::numeric, 2) AS mediana,

    ROUND(PERCENTILE_CONT(0.75)
        WITHIN GROUP (ORDER BY valor_bruto)::numeric, 2) AS q3,

    ROUND(PERCENTILE_CONT(0.90)
        WITHIN GROUP (ORDER BY valor_bruto)::numeric, 2) AS p90,

    ROUND(PERCENTILE_CONT(0.95)
        WITHIN GROUP (ORDER BY valor_bruto)::numeric, 2) AS p95,

    ROUND(PERCENTILE_CONT(0.99)
        WITHIN GROUP (ORDER BY valor_bruto)::numeric, 2) AS p99

FROM transacoes;


-- ------------------------------------------------------------
-- 5. POTENCIAIS OUTLIERS PELO IQR
-- Q1 = 83,72
-- Q3 = 640,92
-- IQR = 557,20
-- Limite superior = 1.476,72
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS qtd_outliers,
    ROUND(
        COUNT(*) * 100.0 /
        (SELECT COUNT(*) FROM transacoes),
        2
    ) AS percentual_outliers
FROM transacoes
WHERE valor_bruto > 1476.72;


-- ------------------------------------------------------------
-- 6. EFEITO DOS VALORES EXTREMOS SOBRE A MÉDIA
-- ------------------------------------------------------------

SELECT
    ROUND(AVG(valor_bruto), 2) AS media_com_outliers,

    ROUND(
        AVG(valor_bruto)
        FILTER (WHERE valor_bruto <= 1476.72),
        2
    ) AS media_sem_outliers

FROM transacoes;


-- ------------------------------------------------------------
-- 7. INVESTIGAÇÃO DOS TICKETS ALTOS POR SEGMENTO
-- ------------------------------------------------------------

SELECT
    e.segmento,
    COUNT(*) AS qtd_transacoes,
    ROUND(AVG(t.valor_bruto), 2) AS ticket_medio

FROM transacoes t

JOIN estabelecimentos e
    ON t.estabelecimento_id = e.estabelecimento_id

WHERE t.valor_bruto > 1476.72

GROUP BY e.segmento
ORDER BY qtd_transacoes DESC;


-- ------------------------------------------------------------
-- 8. PROPORÇÃO DE TICKETS ALTOS POR SEGMENTO
-- ------------------------------------------------------------

SELECT
    e.segmento,
    COUNT(*) AS total_transacoes,

    COUNT(*) FILTER (
        WHERE t.valor_bruto > 1476.72
    ) AS qtd_acima_limite,

    ROUND(
        COUNT(*) FILTER (
            WHERE t.valor_bruto > 1476.72
        ) * 100.0 / COUNT(*),
        2
    ) AS percentual_acima_limite

FROM transacoes t

JOIN estabelecimentos e
    ON t.estabelecimento_id = e.estabelecimento_id

GROUP BY e.segmento
ORDER BY percentual_acima_limite DESC;


-- ------------------------------------------------------------
-- 9. VARIÂNCIA E DESVIO PADRÃO
-- ------------------------------------------------------------

SELECT
    ROUND(AVG(valor_bruto), 2) AS media,
    ROUND(STDDEV(valor_bruto), 2) AS desvio_padrao,
    ROUND(VARIANCE(valor_bruto), 2) AS variancia
FROM transacoes;


-- ------------------------------------------------------------
-- 10. DISPERSÃO POR SEGMENTO
-- ------------------------------------------------------------

SELECT
    e.segmento,
    ROUND(AVG(t.valor_bruto), 2) AS media,
    ROUND(STDDEV(t.valor_bruto), 2) AS desvio_padrao

FROM transacoes t

JOIN estabelecimentos e
    ON t.estabelecimento_id = e.estabelecimento_id

GROUP BY e.segmento
ORDER BY desvio_padrao DESC;


-- ------------------------------------------------------------
-- 11. COEFICIENTE DE VARIAÇÃO
-- ------------------------------------------------------------

SELECT
    e.segmento,

    ROUND(AVG(t.valor_bruto), 2) AS media,

    ROUND(STDDEV(t.valor_bruto), 2) AS desvio_padrao,

    ROUND(
        STDDEV(t.valor_bruto)
        / AVG(t.valor_bruto) * 100,
        2
    ) AS coef_variacao_pct

FROM transacoes t

JOIN estabelecimentos e
    ON t.estabelecimento_id = e.estabelecimento_id

GROUP BY e.segmento
ORDER BY coef_variacao_pct DESC;