/**
 * 中考英语助手 - 前端脚本
 */

// 页面加载完成后执行
document.addEventListener('DOMContentLoaded', function() {
    // 初始化所有工具提示
    var tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'));
    var tooltipList = tooltipTriggerList.map(function (tooltipTriggerEl) {
        return new bootstrap.Tooltip(tooltipTriggerEl);
    });

    // 音频播放器增强
    const audioPlayers = document.querySelectorAll('audio');
    audioPlayers.forEach(player => {
        player.addEventListener('play', function() {
            console.log('开始播放音频');
        });

        player.addEventListener('error', function(e) {
            console.error('音频加载失败:', e);
            alert('音频加载失败，请刷新页面重试');
        });
    });

    // 表单自动保存（草稿）
    const essayTextarea = document.getElementById('essay');
    if (essayTextarea) {
        // 从 localStorage 恢复草稿
        const draft = localStorage.getItem('essay_draft');
        if (draft && essayTextarea.value === '') {
            if (confirm('检测到未完成的草稿，是否恢复？')) {
                essayTextarea.value = draft;
            }
        }

        // 自动保存草稿
        let saveTimeout;
        essayTextarea.addEventListener('input', function() {
            clearTimeout(saveTimeout);
            saveTimeout = setTimeout(() => {
                localStorage.setItem('essay_draft', essayTextarea.value);
                console.log('草稿已自动保存');
            }, 2000);
        });

        // 提交后清除草稿
        const form = essayTextarea.closest('form');
        if (form) {
            form.addEventListener('submit', function() {
                localStorage.removeItem('essay_draft');
            });
        }
    }

    // 字数统计
    const textareas = document.querySelectorAll('textarea');
    textareas.forEach(textarea => {
        const wordCountDiv = document.createElement('div');
        wordCountDiv.className = 'form-text text-end';
        wordCountDiv.id = textarea.id + '_word_count';
        textarea.parentNode.insertBefore(wordCountDiv, textarea.nextSibling);

        function updateWordCount() {
            const text = textarea.value.trim();
            const wordCount = text ? text.split(/\s+/).length : 0;
            wordCountDiv.textContent = `字数：${wordCount}`;
        }

        textarea.addEventListener('input', updateWordCount);
        updateWordCount();
    });

    // 平滑滚动到锚点
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
            const target = document.querySelector(this.getAttribute('href'));
            if (target) {
                e.preventDefault();
                target.scrollIntoView({
                    behavior: 'smooth',
                    block: 'start'
                });
            }
        });
    });

    // 答案提交确认
    const submitButtons = document.querySelectorAll('form button[type="submit"]');
    submitButtons.forEach(button => {
        button.addEventListener('click', function(e) {
            const form = this.closest('form');
            if (!form.classList.contains('was-validated')) {
                // 第一次点击，只验证
                return;
            }
            // 可选：添加二次确认
            // if (!confirm('确认提交答案吗？')) {
            //     e.preventDefault();
            // }
        });
    });
});

// 工具函数：显示加载提示
function showLoading(message = '加载中...') {
    const loadingDiv = document.createElement('div');
    loadingDiv.id = 'globalLoading';
    loadingDiv.className = 'position-fixed top-50 start-50 translate-middle';
    loadingDiv.style.zIndex = '9999';
    loadingDiv.innerHTML = `
        <div class="card shadow-lg">
            <div class="card-body text-center p-4">
                <div class="spinner-border text-primary mb-3" role="status">
                    <span class="visually-hidden">Loading...</span>
                </div>
                <p class="mb-0">${message}</p>
            </div>
        </div>
    `;
    document.body.appendChild(loadingDiv);
}

// 工具函数：隐藏加载提示
function hideLoading() {
    const loadingDiv = document.getElementById('globalLoading');
    if (loadingDiv) {
        loadingDiv.remove();
    }
}

// 工具函数：显示通知
function showNotification(message, type = 'info') {
    const alertDiv = document.createElement('div');
    alertDiv.className = `alert alert-${type} alert-dismissible fade show position-fixed top-0 start-50 translate-middle-x mt-3`;
    alertDiv.style.zIndex = '9999';
    alertDiv.innerHTML = `
        ${message}
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;
    document.body.appendChild(alertDiv);

    // 3秒后自动消失
    setTimeout(() => {
        alertDiv.classList.remove('show');
        setTimeout(() => alertDiv.remove(), 150);
    }, 3000);
}

// 键盘快捷键
document.addEventListener('keydown', function(e) {
    // Ctrl/Cmd + S: 保存草稿（阻止浏览器默认保存）
    if ((e.ctrlKey || e.metaKey) && e.key === 's') {
        const essayTextarea = document.getElementById('essay');
        if (essayTextarea) {
            e.preventDefault();
            localStorage.setItem('essay_draft', essayTextarea.value);
            showNotification('草稿已保存', 'success');
        }
    }
});

// 页面可见性变化时的处理
document.addEventListener('visibilitychange', function() {
    if (document.hidden) {
        console.log('页面隐藏，暂停音频播放');
        document.querySelectorAll('audio').forEach(audio => audio.pause());
    }
});

// 错误处理
window.addEventListener('error', function(e) {
    console.error('页面错误:', e.error);
    // 生产环境可以发送错误日志到服务器
});

// 检测网络状态
window.addEventListener('online', function() {
    showNotification('网络已连接', 'success');
});

window.addEventListener('offline', function() {
    showNotification('网络已断开，部分功能可能无法使用', 'warning');
});
