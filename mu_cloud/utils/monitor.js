/**
 * 应用监控工具
 * 负责收集和上报应用运行时的各项指标和错误
 * 
 * 功能：
 * 1. 性能监控(API响应时间、页面加载时间)
 * 2. 错误监控(JS错误、API错误)
 * 3. 行为统计(关键操作日志)
 * 
 * @module utils/monitor
 * @version 1.0.0
 * @since 2025-05-12
 */

class Monitor {
  constructor() {
    this.queue = []
    this.reportUrl = 'https://monitor.yourdomain.com/api/report'
    this.isReporting = false
  }

  /**
   * 记录性能指标
   * @param {string} metricName 指标名称 
   * @param {number} value 指标值
   * @param {Object} [tags={}] 附加标签
   */
  trackPerformance(metricName, value, tags = {}) {
    this._addToQueue({
      type: 'performance',
      name: metricName,
      value,
      tags,
      timestamp: Date.now()
    })
  }

  /**
   * 记录错误信息
   * @param {Error} error 错误对象
   * @param {Object} [context={}] 错误上下文
   */
  trackError(error, context = {}) {
    this._addToQueue({
      type: 'error',
      name: error.name,
      message: error.message,
      stack: error.stack,
      context,
      timestamp: Date.now()
    })
  }

  /**
   * 记录关键操作
   * @param {string} action 操作名称
   * @param {Object} [params={}] 操作参数 
   */
  trackAction(action, params = {}) {
    this._addToQueue({
      type: 'action',
      name: action,
      params,
      timestamp: Date.now()
    })
  }

  /**
   * 添加到上报队列
   * @private
   */
  _addToQueue(item) {
    this.queue.push(item)
    if (this.queue.length >= 10) {
      this._report()
    }
  }

  /**
   * 上报数据
   * @private
   */
  async _report() {
    if (this.isReporting || this.queue.length === 0) return
    
    this.isReporting = true
    const items = this.queue.splice(0, 10)
    
    try {
      await wx.request({
        url: this.reportUrl,
        method: 'POST',
        data: { events: items },
        timeout: 5000
      })
    } catch (err) {
      // console.error('监控上报失败:', err)
      // 上报失败重新加入队列
      this.queue.unshift(...items)
    } finally {
      this.isReporting = false
    }
  }
}

// 单例模式导出
module.exports = new Monitor()
