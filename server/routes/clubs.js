const express = require('express');
const router = express.Router();
const Club = require('../models/Club');

/**
 * GET /api/clubs
 * 公开端点 - 获取所有已批准的社团
 * 用于前端地图显示
 * 支持搜索功能
 * 
 * @query {string} search - 搜索关键词（可选）
 * @returns {Array} clubs - 社团列表
 */
router.get('/', async (req, res) => {
  try {
    const { search } = req.query;
    let query = {};

    // 如果有搜索参数，添加搜索条件
    if (search && search.trim()) {
      const searchRegex = new RegExp(search.trim(), 'i');
      query = {
        $or: [
          { name: searchRegex },
          { school: searchRegex },
          { province: searchRegex },
          { city: searchRegex }
        ]
      };
    }

    const clubs = await Club.find(query)
      .select('-__v -sourceSubmission -verifiedBy')
      .sort({ createdAt: -1 })
      .limit(search ? 20 : undefined); // 搜索时限制结果数量

    // 转换为前端期望的格式
    const formattedClubs = clubs.map(club => ({
      id: club.id || club._id.toString(),
      name: club.name,
      school: club.school,
      city: club.city || '',
      province: club.province,
      latitude: club.coordinates[1],  // [lng, lat] -> lat
      longitude: club.coordinates[0], // [lng, lat] -> lng
      img_name: club.logo || '',
      short_description: club.shortDescription || '',
      long_description: club.description || '',
      tags: club.tags || [],
      website: club.website || '',
      contact: club.contact || {},
      shortDescription: club.shortDescription || '',
      description: club.description || '',
      coordinates: club.coordinates
    }));

    return res.status(200).json({
      success: true,
      data: formattedClubs,
      total: formattedClubs.length
    });
  } catch (error) {
    console.error('Get clubs failed:', error);
    return res.status(500).json({
      success: false,
      error: 'SERVER_ERROR',
      message: '获取社团列表失败'
    });
  }
});

/**
 * GET /api/clubs/:id
 * 公开端点 - 获取单个社团详情
 * 
 * @param {string} id - 社团ID
 * @returns {Object} club - 社团详情
 */
router.get('/:id', async (req, res) => {
  try {
    const club = await Club.findById(req.params.id)
      .select('-__v -sourceSubmission -verifiedBy');

    if (!club) {
      return res.status(404).json({
        success: false,
        error: 'NOT_FOUND',
        message: '未找到该社团'
      });
    }

    const formattedClub = {
      id: club._id.toString(),
      name: club.name,
      school: club.school,
      city: club.city || '',
      province: club.province,
      latitude: club.coordinates[1],
      longitude: club.coordinates[0],
      img_name: club.logo || '',
      short_description: club.shortDescription || '',
      long_description: club.description || '',
      tags: club.tags || [],
      website: club.website || '',
      contact: club.contact || {}
    };

    return res.status(200).json({
      success: true,
      data: formattedClub
    });
  } catch (error) {
    console.error('Get club failed:', error);
    return res.status(500).json({
      success: false,
      error: 'SERVER_ERROR',
      message: '获取社团详情失败'
    });
  }
});

module.exports = router;
