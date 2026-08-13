-- ============================================================
-- PROJETO: Análise Estatística de Dados Transacionais
-- ETAPA 03: Segmentação por Dimensão — Taxa de Aprovação
-- ============================================================
--
-- NOTA METODOLÓGICA (sincronizado com 02_eda_complementar.ipynb):
-- taxa_aprovacao_pct = aprovadas / (aprovadas + negadas). Todas as
-- queries abaixo filtram status_id IN (1, 2), excluindo Cancelada
-- (3) e Estornada (4) — eventos pós-aprovação, não resultado de
-- uma tentativa de autorização. Validado contra dashboard de
-- Power BI já existente (TPV, aprovadas e ticket médio bateram
-- exatamente; só a taxa de aprovação precisou dessa correção).
-- ============================================================


-- ------------------------------------------------------------
-- 1. TAXA DE APROVAÇÃO GERAL (BASELINE)
-- Régua de comparação para todas as dimensões a seguir.
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_transacoes,
    COUNT(*) FILTER (WHERE status_id = 1) AS total_aprovadas,
    ROUND(
        COUNT(*) FILTER (WHERE status_id = 1) * 100.0 / COUNT(*),
        2
    ) AS taxa_aprovacao_pct
FROM transacoes
WHERE status_id IN (1, 2);  -- exclui Cancelada/Estornada: evento pós-aprovação, não é tentativa


-- ------------------------------------------------------------
-- 2. TAXA DE APROVAÇÃO POR BANDEIRA
-- LEFT JOIN + COALESCE por precaução: bandeira_id = 0 é o
-- sentinela de PIX ("Não se aplica"), documentado na tabela
-- bandeiras, não um valor nulo.
-- ------------------------------------------------------------

SELECT
    COALESCE(b.bandeira, 'Sem bandeira (provável PIX)') AS bandeira,
    COUNT(*) AS total_transacoes,
    COUNT(*) FILTER (WHERE t.status_id = 1) AS total_aprovadas,
    ROUND(
        COUNT(*) FILTER (WHERE t.status_id = 1) * 100.0 / COUNT(*),
        2
    ) AS taxa_aprovacao_pct
FROM transacoes t
LEFT JOIN bandeiras b
    ON t.bandeira_id = b.bandeira_id
WHERE t.status_id IN (1, 2)  -- exclui Cancelada/Estornada
GROUP BY COALESCE(b.bandeira, 'Sem bandeira (provável PIX)')
ORDER BY taxa_aprovacao_pct DESC;


-- ------------------------------------------------------------
-- 3. TAXA DE APROVAÇÃO POR ADQUIRENTE
-- ------------------------------------------------------------

SELECT
    a.nome_resumido AS adquirente,
    COUNT(*) AS total_transacoes,
    COUNT(*) FILTER (WHERE t.status_id = 1) AS total_aprovadas,
    ROUND(
        COUNT(*) FILTER (WHERE t.status_id = 1) * 100.0 / COUNT(*),
        2
    ) AS taxa_aprovacao_pct
FROM transacoes t
LEFT JOIN adquirentes a
    ON t.adquirente_id = a.adquirente_id
WHERE t.status_id IN (1, 2)  -- exclui Cancelada/Estornada
GROUP BY a.nome_resumido
ORDER BY taxa_aprovacao_pct DESC;


-- ------------------------------------------------------------
-- 4. TAXA DE APROVAÇÃO POR CANAL DE CAPTURA
-- ------------------------------------------------------------

SELECT
    c.canal_captura,
    COUNT(*) AS total_transacoes,
    COUNT(*) FILTER (WHERE t.status_id = 1) AS total_aprovadas,
    ROUND(
        COUNT(*) FILTER (WHERE t.status_id = 1) * 100.0 / COUNT(*),
        2
    ) AS taxa_aprovacao_pct
FROM transacoes t
LEFT JOIN canais_captura c
    ON t.canal_captura_id = c.canal_captura_id
WHERE t.status_id IN (1, 2)  -- exclui Cancelada/Estornada
GROUP BY c.canal_captura
ORDER BY taxa_aprovacao_pct DESC;


-- ------------------------------------------------------------
-- 5. TAXA DE APROVAÇÃO POR HORÁRIO DO DIA
-- Volume desigual entre madrugada e horário comercial: as
-- taxas de madrugada são estimativas menos estáveis (menos
-- transações por hora).
-- ------------------------------------------------------------

SELECT
    EXTRACT(HOUR FROM hora_transacao) AS hora_do_dia,
    COUNT(*) AS total_transacoes,
    COUNT(*) FILTER (WHERE status_id = 1) AS total_aprovadas,
    ROUND(
        COUNT(*) FILTER (WHERE status_id = 1) * 100.0 / COUNT(*),
        2
    ) AS taxa_aprovacao_pct
FROM transacoes
WHERE status_id IN (1, 2)  -- exclui Cancelada/Estornada
GROUP BY EXTRACT(HOUR FROM hora_transacao)
ORDER BY hora_do_dia;


-- ------------------------------------------------------------
-- 6. TAXA DE APROVAÇÃO POR MEIO DE PAGAMENTO
-- Separa Débito de Crédito (agregados em "Cartão" nos testes
-- de PIX x Cartão) e reproduz a taxa de PIX já vista por
-- bandeira, agora sob o agrupamento correto de meio_pagamento.
-- ------------------------------------------------------------

SELECT
    m.meio_pagamento,
    COUNT(*) AS total_transacoes,
    COUNT(*) FILTER (WHERE t.status_id = 1) AS total_aprovadas,
    ROUND(
        COUNT(*) FILTER (WHERE t.status_id = 1) * 100.0 / COUNT(*),
        2
    ) AS taxa_aprovacao_pct
FROM transacoes t
JOIN meios_pagamento m
    ON t.meio_pagamento_id = m.meio_pagamento_id
WHERE t.status_id IN (1, 2)  -- exclui Cancelada/Estornada
GROUP BY m.meio_pagamento
ORDER BY taxa_aprovacao_pct DESC;
