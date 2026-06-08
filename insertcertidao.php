<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: *");
header("Content-Type: application/json; charset=UTF-8");

// tenta incluir conexao em caminhos prováveis (silencioso)
$possible = [
    __DIR__ . '/conexaoHomologacao.php',
    __DIR__ . '/../conexaoHomologacao.php',
    __DIR__ . '/../../conexaoHomologacao.php'
];

$included = false;
foreach ($possible as $p) {
    if (file_exists($p)) {
        include_once $p;
        $included = true;
        break;
    }
}

if (!$included) {
    http_response_code(500);
    echo json_encode([
        "code" => 0,
        "message" => "Erro interno: arquivo de conexão não encontrado.",
        "result" => []
    ]);
    exit;
}

// Parâmetros via GET (alguns opcionais, com valores padrão conforme SQL fornecido)
// Conforme solicitado:
// - soce_data: NOW() (não enviado via GET)
// - soce_ativo: 1 (fixo)
// - fk_poli_mili_matricula: enviado via GET (obrigatório)
// - fk_tice_cod: enviado via GET (obrigatório)
// - soce_data_vencimento: NULL
// - fk_stce_cod: deixado ao DEFAULT do banco (omitido da query)
// - soce_arquivo: NULL
// - soce_obs: NULL
// - soce_justificativa: opcional via GET

$matricula = isset($_GET['fk_poli_mili_matricula']) ? trim($_GET['fk_poli_mili_matricula']) : null;
$tice_cod = isset($_GET['fk_tice_cod']) ? trim($_GET['fk_tice_cod']) : null;
$justificativa = isset($_GET['soce_justificativa']) ? trim($_GET['soce_justificativa']) : null;

if ($matricula === null || $matricula === '') {
    echo json_encode([
        "code" => 0,
        "message" => "Parâmetro 'fk_poli_mili_matricula' não informado.",
        "result" => []
    ]);
    exit;
}

if ($tice_cod === null || $tice_cod === '') {
    echo json_encode([
        "code" => 0,
        "message" => "Parâmetro 'fk_tice_cod' não informado.",
        "result" => []
    ]);
    exit;
}

try {
    if (!isset($conexaoPdo) || !($conexaoPdo instanceof PDO)) {
        http_response_code(500);
        echo json_encode([
            "code" => 0,
            "message" => "Erro interno: conexão com o banco inválida.",
            "result" => []
        ]);
        exit;
    }


    // Insert com fk_stce_cod fixo em 1 (Solicitada)
    $sql = "INSERT INTO recursoshumanos.solicitacao_certidao
        (soce_cod, soce_data, soce_ativo, fk_poli_mili_matricula, fk_tice_cod, soce_data_vencimento, fk_stce_cod, soce_arquivo, soce_obs, soce_justificativa)
        VALUES(nextval('recursoshumanos.solicitacao_certidao_soce_cod_seq'::regclass), now(), 1, :matricula, :tice_cod, NULL, 1, NULL, NULL, :justificativa)
        RETURNING soce_cod";

    $stmt = $conexaoPdo->prepare($sql);
    $stmt->bindValue(':matricula', $matricula, PDO::PARAM_INT);
    $stmt->bindValue(':tice_cod', $tice_cod, PDO::PARAM_INT);
    if ($justificativa === null || $justificativa === '') {
        $stmt->bindValue(':justificativa', null, PDO::PARAM_NULL);
    } else {
        $stmt->bindValue(':justificativa', $justificativa, PDO::PARAM_STR);
    }

    $stmt->execute();

    $insertedId = $stmt->fetchColumn();

    if ($insertedId === false) {
        echo json_encode([
            "code" => 0,
            "message" => "Falha ao inserir a certidão.",
            "result" => []
        ]);
        exit;
    }

    echo json_encode([
        "code" => 1,
        "message" => "Certidão inserida com sucesso.",
        "result" => [
            "soce_cod" => intval($insertedId),
            "fk_poli_mili_matricula" => $matricula,
            "fk_tice_cod" => $tice_cod,
            "soce_data_vencimento" => null,
            "fk_stce_cod" => 1,
            "soce_arquivo" => null
        ]
    ]);

    // limpeza
    $stmt = null;
    $conexaoPdo = null;
    exit;
} catch (PDOException $e) {
    error_log("insertcertidao.php PDO error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        "code" => 0,
        "message" => "Erro ao inserir no banco de dados.",
        "result" => []
    ]);
    exit;
}
?>
