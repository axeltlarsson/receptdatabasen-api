import { rest_service, resetdb, login } from '../common'
import should from 'should'

describe('read', function () {
  before(function (done) {
    resetdb()
    login(done)
  })

  after(function (done) { resetdb(); done() })

  it('basic', function (done) {
    rest_service()
      .get('/rest/recipes?select=id,title')
      .expect('Content-Type', /json/)
      .expect(r => {
        r.body.length.should.equal(7)
        r.body[0].id.should.equal(1)
      })
      .expect(200, done)
  })

  it('by primary key', function (done) {
    rest_service()
      .get('/rest/recipes/1?select=id,title')
      .expect(r => {
        r.body.id.should.equal(1)
        r.body.title.should.equal('Cheese Cake')
      })
      .expect(200, done)
  })
})
