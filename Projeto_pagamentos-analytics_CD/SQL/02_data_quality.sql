-- ============================================================
-- PROJETO: Análise Estatística de Dados Transacionais
-- ETAPA 02: Data Quality
-- ============================================================


-- ------------------------------------------------------------
-- 1. COMPLETUDE E VALIDADE DAS COLUNAS CENTRAIS
-- Verifica nulos e valores fora do domínio esperado em
-- transacoes. Resultado esperado: todas as contagens em zero.
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_linhas,
    COUNT(*) FILTER (WHERE valor_bruto IS NULL) AS nulos_valor_bruto,
    COUNT(*) FILTER (WHERE quantidade_parcelas IS NULL) AS nulos_parcelas,
    COUNT(*) FILTER (WHERE data_transacao IS NULL) AS nulos_data,
    COUNT(*) FILTER (WHERE hora_transacao IS NULL) AS nulos_hora,
    COUNT(*) FILTER (WHERE estabelecimento_id IS NULL) AS nulos_estabelecimento,
    COUNT(*) FILTER (WHERE meio_pagamento_id IS NULL) AS nulos_meio_pagamento,
    COUNT(*) FILTER (WHERE valor_bruto <= 0) AS valor_impossivel,
    COUNT(*) FILTER (WHERE quantidade_parcelas <= 0) AS parcelas_impossivel
FROM transacoes;


-- ------------------------------------------------------------
-- 2. DUPLICIDADE LÓGICA DE NEGÓCIO
-- transacao_id é chave primária (duplicidade técnica já é
-- impedida pela constraint). Aqui verificamos duplicidade de
-- EVENTO: mesma data, hora, valor e identificador de captura.
--
-- PIX não preenche codigo_autorizacao (usa txid_pix); cartão
-- não preenche txid_pix (usa codigo_autorizacao). Por isso o
-- identificador é unificado com COALESCE.
-- ------------------------------------------------------------

SELECT
    data_transacao,
    hora_transacao,
    valor_bruto,
    COALESCE(codigo_autorizacao, txid_pix) AS identificador_transacao,
    COUNT(*) AS qtd_ocorrencias
FROM transacoes
WHERE codigo_autorizacao IS NOT NULL OR txid_pix IS NOT NULL
GROUP BY data_transacao, hora_transacao, valor_bruto, COALESCE(codigo_autorizacao, txid_pix)
HAVING COUNT(*) > 1
ORDER BY qtd_ocorrencias DESC;


-- ------------------------------------------------------------
-- 3. COINCIDÊNCIA DE FINGERPRINT (mesma data/hora/valor,
-- identificadores diferentes)
-- Diferencia duplicidade real de coincidência estatística:
-- se qtd_identificadores_distintos = qtd_transacoes, são
-- eventos genuinamente distintos que coincidiram no tempo.
-- ------------------------------------------------------------

SELECT
    data_transacao,
    hora_transacao,
    valor_bruto,
    COUNT(*) AS qtd_transacoes,
    COUNT(DISTINCT COALESCE(codigo_autorizacao, txid_pix)) AS qtd_identificadores_distintos
FROM transacoes
WHERE codigo_autorizacao IS NOT NULL OR txid_pix IS NOT NULL
GROUP BY data_transacao, hora_transacao, valor_bruto
HAVING COUNT(*) > 1
ORDER BY qtd_transacoes DESC;


-- ------------------------------------------------------------
-- 4. VALIDAÇÃO DO SENTINELA motivo_negativa_id = 0
-- Confirma que o valor usado para "transação aprovada" (sem
-- motivo de negativa) está de fato documentado na tabela de
-- lookup, e não é uma exceção fora da integridade referencial.
-- ------------------------------------------------------------

SELECT *
FROM motivos_negativa
WHERE motivo_negativa_id = 0;


-- ------------------------------------------------------------
-- 5. CONSISTÊNCIA POR MEIO DE PAGAMENTO
-- Confirma o padrão observado: PIX (meio_pagamento_id = 1) usa
-- txid_pix; Débito/Crédito usam codigo_autorizacao. Nenhuma
-- linha deveria preencher os dois ao mesmo tempo.
--
-- RESULTADO: preencheu_os_dois = 0 em todos os meios (ok).
-- nao_preencheu_nenhum NÃO é zero para Débito (4.644) e Crédito
-- (18.505) - investigado no bloco 6 a seguir, que explica o
-- porquê (não é um problema de qualidade).
-- ------------------------------------------------------------

SELECT
    meio_pagamento_id,
    COUNT(*) AS total,
    COUNT(*) FILTER (WHERE codigo_autorizacao IS NOT NULL AND txid_pix IS NOT NULL) AS preencheu_os_dois,
    COUNT(*) FILTER (WHERE codigo_autorizacao IS NULL AND txid_pix IS NULL) AS nao_preencheu_nenhum
FROM transacoes
GROUP BY meio_pagamento_id
ORDER BY meio_pagamento_id;


-- ------------------------------------------------------------
-- 6. AUSÊNCIA DE IDENTIFICADOR × STATUS DA TRANSAÇÃO
-- Cruza o resultado do bloco 5 com status_id para entender a
-- causa. Confirma o ciclo de vida real: uma transação só pode
-- ser Cancelada (3) ou Estornada (4) se antes foi Aprovada (1),
-- logo carrega codigo_autorizacao/txid_pix. Uma transação
-- Negada (2) nunca chegou a ser autorizada.
--
-- ALERTA DE DATA LEAKAGE: codigo_autorizacao/txid_pix estarem
-- nulos é, na prática, quase um proxy perfeito de status_id =
-- Negada para transações de cartão. Essas colunas não podem
-- virar feature de um futuro modelo que tente prever aprovação,
-- porque não estariam disponíveis no momento da previsão real.
-- ------------------------------------------------------------

SELECT
    meio_pagamento_id,
    status_id,
    COUNT(*) AS total,
    COUNT(*) FILTER (WHERE codigo_autorizacao IS NULL AND txid_pix IS NULL) AS nao_preencheu_nenhum
FROM transacoes
GROUP BY meio_pagamento_id, status_id
ORDER BY meio_pagamento_id, status_id;


-- ------------------------------------------------------------
-- 7. CONSISTÊNCIA status_id × motivo_negativa_id (sentido 1)
-- Toda transação aprovada (status_id = 1) deve usar o sentinela
-- motivo_negativa_id = 0. Resultado esperado: nenhuma linha.
-- ------------------------------------------------------------

SELECT *
FROM transacoes
WHERE status_id = 1
  AND motivo_negativa_id <> 0;


-- ------------------------------------------------------------
-- 8. CONSISTÊNCIA status_id × motivo_negativa_id (sentido 2)
-- Nenhuma transação negada (status_id = 2) deveria usar o
-- sentinela 0, já que uma negativa sempre tem motivo registrado.
-- Resultado esperado: nenhuma linha.
-- ------------------------------------------------------------

SELECT *
FROM transacoes
WHERE status_id = 2
  AND motivo_negativa_id = 0;
